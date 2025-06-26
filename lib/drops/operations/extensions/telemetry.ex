defmodule Drops.Operations.Extensions.Telemetry do
  @moduledoc """
  Telemetry extension for Operations.

  This extension adds telemetry event emission to Operations modules when
  telemetry is enabled. By default, it emits operation-level events that wrap
  the entire operation processing (UoW pipeline + execute step).

  ## Events Emitted

  The extension can emit two types of telemetry events:

  ### Operation-Level Events (Default)
  - `[<prefix>, :operation, :start]` - Before operation processing begins
  - `[<prefix>, :operation, :stop]` - After operation processing completes

  ### Step-Level Events (Additional Detail)
  - `[<prefix>, :step, :start]` - Before each step execution
  - `[<prefix>, :step, :stop]` - After step execution completes

  By default, the prefix is `[:drops, :operations]`, but you can customize it
  using configuration options.

  ## Event Metadata

  All events include the following metadata:

  - `:operation` - The operation module name
  - `:operation_type` - The operation type (e.g., `:command`, `:query`, `:form`)
  - `:step` - The step name (only for step-level events)

  ## Event Measurements

  - `:start` events include `:system_time` (when processing started)
  - `:stop` events include `:duration` (processing time in native units)

  ## Usage

  Enable operation-level telemetry (default behavior):

      defmodule MyApp.CreateUser do
        use MyApp.Operations, type: :command, telemetry: true
      end

  ## Configuration Options

  ### Operation-Level Events (Default)

      # Simple boolean - enables operation-level events with default prefix
      telemetry: true

      # Custom prefix for operation-level events
      telemetry: [prefix: [:my_app, :operations]]

      # Explicit operation-level configuration
      telemetry: [level: :operation, prefix: [:my_app, :operations]]

  ### Step-Level Events

      # Enable step-level events for all steps
      telemetry: :steps

      # Enable step-level events with custom prefix
      telemetry: [level: :steps, prefix: [:my_app, :operations]]

      # Enable step-level events for specific steps only
      telemetry: [level: :steps, steps: [:execute]]

  ### Both Event Types (Full Observability)

      # Enable both operation and step-level events
      telemetry: [level: :both, prefix: [:my_app, :operations]]

      # Enable both with specific steps only
      telemetry: [level: :both, steps: [:prepare, :validate]]

  ## Attaching Handlers

  For operation-level events:

      :telemetry.attach_many(
        "my-operations-handler",
        [
          [:my_app, :operations, :operation, :start],
          [:my_app, :operations, :operation, :stop]
        ],
        &MyApp.TelemetryHandler.handle_event/4,
        %{}
      )

  For step-level events:

      :telemetry.attach_many(
        "my-steps-handler",
        [
          [:my_app, :operations, :step, :start],
          [:my_app, :operations, :step, :stop]
        ],
        &MyApp.TelemetryHandler.handle_event/4,
        %{}
      )

  """

  @behaviour Drops.Operations.Extension

  @impl true
  def enabled?(opts) do
    telemetry_opt = Keyword.get(opts, :telemetry, false)

    telemetry_opt == true or telemetry_opt == :steps or
      (is_list(telemetry_opt) and telemetry_opt != [])
  end

  @impl true
  def extend_using_macro(_opts) do
    quote do
      # No additional setup needed in the main __using__ macro
    end
  end

  @impl true
  def extend_operation_runtime(_opts) do
    quote do
      # No additional runtime code needed
    end
  end

  @impl true
  def extend_operation_definition(opts) do
    # Parse telemetry configuration
    telemetry_config = parse_telemetry_config(opts)

    # Only inject execute-level telemetry for step-level configurations
    if telemetry_config.level == :steps and
         :execute in get_monitored_steps(telemetry_config, [:execute]) do
      # Inject telemetry-aware execute functions for step-level telemetry
      quote do
        # Store telemetry config for use in execute functions
        @telemetry_config unquote(Macro.escape(telemetry_config))

        # Override the execute functions to add telemetry
        defoverridable execute: 1, execute: 2

        def execute(context) do
          Drops.Operations.Extensions.Telemetry.execute_with_telemetry(
            __MODULE__,
            context,
            @telemetry_config,
            fn -> super(context) end
          )
        end

        def execute(previous_result, context) do
          Drops.Operations.Extensions.Telemetry.execute_with_telemetry(
            __MODULE__,
            {previous_result, context},
            @telemetry_config,
            fn -> super(previous_result, context) end
          )
        end
      end
    else
      quote do
        # No step-level telemetry for execute step
      end
    end
  end

  @impl true
  def extend_unit_of_work(uow, opts) do
    # Get operation metadata for telemetry events
    operation_module = uow.operation_module
    operation_type = Keyword.get(opts, :type, :unknown)

    # Parse telemetry configuration
    telemetry_config = parse_telemetry_config(opts)

    # Determine what type of telemetry to configure
    extended_uow =
      case telemetry_config.level do
        :operation ->
          # Configure operation-level telemetry
          Map.put(uow, :operation_telemetry_config, %{
            operation: operation_module,
            operation_type: operation_type,
            telemetry_prefix: telemetry_config.prefix
          })

        :steps ->
          # Configure step-level telemetry (backward compatibility)
          configure_step_level_telemetry(
            uow,
            telemetry_config,
            operation_module,
            operation_type
          )

        :both ->
          # Configure both operation and step-level telemetry
          # For :both level, exclude :execute from step-level since operation-level handles it
          step_config = %{
            telemetry_config
            | steps: exclude_execute_step(telemetry_config.steps)
          }

          uow
          |> Map.put(:operation_telemetry_config, %{
            operation: operation_module,
            operation_type: operation_type,
            telemetry_prefix: telemetry_config.prefix
          })
          |> configure_step_level_telemetry(
            step_config,
            operation_module,
            operation_type
          )
      end

    extended_uow
  end

  @doc """
  Wraps step execution with telemetry events including duration measurement.
  """
  def emit_around_event(step, _context, next_fn, config) do
    start_time = System.monotonic_time()

    metadata = Map.put(config, :step, step)
    telemetry_prefix = Map.get(config, :telemetry_prefix, [:drops, :operations])

    :telemetry.execute(
      telemetry_prefix ++ [:step, :start],
      %{system_time: System.system_time()},
      metadata
    )

    result = next_fn.()

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      telemetry_prefix ++ [:step, :stop],
      %{duration: duration},
      metadata
    )

    result
  end

  # Private helper functions

  defp configure_step_level_telemetry(
         uow,
         telemetry_config,
         operation_module,
         operation_type
       ) do
    # Get steps to monitor based on configuration
    available_steps = Map.keys(uow.steps)
    monitored_steps = get_monitored_steps(telemetry_config, available_steps)

    # Filter out :execute step since it's not processed through UnitOfWork pipeline
    pipeline_steps = monitored_steps -- [:execute]

    # Register telemetry callbacks for pipeline steps only
    # Use around callbacks only to get accurate timing and handle exceptions
    extended_uow =
      Enum.reduce(pipeline_steps, uow, fn step, acc_uow ->
        acc_uow
        |> Drops.Operations.UnitOfWork.register_around_callback(
          step,
          __MODULE__,
          :emit_around_event,
          %{
            operation: operation_module,
            operation_type: operation_type,
            telemetry_prefix: telemetry_config.prefix
          }
        )
      end)

    # If :execute is monitored, store telemetry config for Operations module to use
    final_uow =
      if :execute in monitored_steps do
        Map.put(extended_uow, :execute_telemetry_config, %{
          operation: operation_module,
          operation_type: operation_type,
          telemetry_prefix: telemetry_config.prefix
        })
      else
        extended_uow
      end

    # Preserve any existing operation_telemetry_config that might have been set
    case Map.get(uow, :operation_telemetry_config) do
      nil ->
        final_uow

      operation_config ->
        Map.put(final_uow, :operation_telemetry_config, operation_config)
    end
  end

  defp parse_telemetry_config(opts) do
    telemetry_opt = Keyword.get(opts, :telemetry, false)
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, [:drops, :operations])

    case telemetry_opt do
      true ->
        # Default: operation-level events
        %{level: :operation, prefix: telemetry_prefix}

      :steps ->
        %{level: :steps, prefix: telemetry_prefix, steps: :all}

      config when is_list(config) ->
        # New configuration format
        level = Keyword.get(config, :level, :operation)
        prefix = Keyword.get(config, :prefix, telemetry_prefix)
        steps = Keyword.get(config, :steps, :all)
        %{level: level, prefix: prefix, steps: steps}

      _ ->
        # Fallback (shouldn't happen if enabled?/1 is correct)
        %{level: :operation, prefix: telemetry_prefix}
    end
  end

  defp get_monitored_steps(%{steps: :all}, available_steps), do: available_steps

  defp get_monitored_steps(%{steps: steps}, available_steps) when is_list(steps) do
    # Only include steps that are both requested and available
    Enum.filter(steps, &(&1 in available_steps))
  end

  # For operation-level configs that don't have steps, return empty list
  defp get_monitored_steps(_config, _available_steps), do: []

  # Helper to exclude :execute step from step-level monitoring when operation-level is also enabled
  defp exclude_execute_step(:all), do: [:conform, :prepare, :validate]
  defp exclude_execute_step(steps) when is_list(steps), do: steps -- [:execute]

  @doc """
  Wraps entire operation execution with telemetry events. This is called by the Operations module
  to emit operation-level start/stop events around the entire UoW processing + execute step.
  """
  def emit_operation_telemetry(operation_module, _context, config, operation_fn) do
    start_time = System.monotonic_time()

    metadata = %{
      operation: Map.get(config, :operation, operation_module),
      operation_type: Map.get(config, :operation_type, :unknown)
    }

    telemetry_prefix = Map.get(config, :telemetry_prefix, [:drops, :operations])

    :telemetry.execute(
      telemetry_prefix ++ [:operation, :start],
      %{system_time: System.system_time()},
      metadata
    )

    result = operation_fn.()

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      telemetry_prefix ++ [:operation, :stop],
      %{duration: duration},
      metadata
    )

    result
  end

  @doc """
  Wraps execute step with telemetry events. This is called directly by the Operations module
  since :execute is not processed through the UnitOfWork pipeline.
  """
  def emit_execute_telemetry(execute_fn, config) do
    start_time = System.monotonic_time()

    metadata = Map.put(config, :step, :execute)
    telemetry_prefix = Map.get(config, :telemetry_prefix, [:drops, :operations])

    :telemetry.execute(
      telemetry_prefix ++ [:step, :start],
      %{system_time: System.system_time()},
      metadata
    )

    result = execute_fn.()

    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      telemetry_prefix ++ [:step, :stop],
      %{duration: duration},
      metadata
    )

    result
  end
end
