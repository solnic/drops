defmodule Drops.Operations.Extensions.Telemetry do
  @moduledoc """
  Telemetry extension for Operations.

  This extension adds telemetry event emission to Operations modules when
  telemetry is enabled. It provides observability hooks for each processing
  step in the UnitOfWork pipeline.

  ## Events Emitted

  The extension emits the following telemetry events:

  - `[<prefix>, :step, :start]` - Before each step execution
  - `[<prefix>, :step, :stop]` - After step execution completes

  By default, the prefix is `[:drops, :operations]`, but you can customize it
  using the `:telemetry_prefix` option or the new configuration format.

  ## Event Metadata

  All events include the following metadata:

  - `:operation` - The operation module name
  - `:step` - The step name (e.g., `:conform`, `:prepare`, `:validate`, `:execute`)
  - `:operation_type` - The operation type (e.g., `:command`, `:query`, `:form`)

  ## Event Measurements

  - `:start` events include `:system_time` (when the step started)
  - `:stop` events include `:duration` (step execution time in native units)

  ## Usage

  Enable telemetry by adding the `:telemetry` option to your Operations module:

      defmodule MyApp.Operations do
        use Drops.Operations, telemetry: true
      end

  Or enable it for specific operations:

      defmodule MyApp.CreateUser do
        use MyApp.Operations, type: :command, telemetry: true
      end

  ## Customizing Event Names and Steps

  You can customize the telemetry event prefix using the `:telemetry_prefix` option:

      defmodule MyApp.Operations do
        use Drops.Operations, telemetry: true, telemetry_prefix: [:my_app, :operations]
      end

  This will emit events like `[:my_app, :operations, :step, :start]` instead of the default
  `[:drops, :operations, :step, :start]`.

  Alternatively, you can use the new configuration format to specify both prefix and steps:

      defmodule MyApp.CreateUser do
        use MyApp.Operations,
          type: :command,
          telemetry: [prefix: [:my_app, :commands], steps: [:execute]]
      end

  This will only emit telemetry events for the `:execute` step with the custom prefix
  `[:my_app, :commands]`.

  ## Configuration Options

  When using the map/keyword configuration format, the following options are supported:

  - `:prefix` - Custom event prefix (defaults to `[:drops, :operations]`)
  - `:steps` - List of steps to emit events for (defaults to all available steps)

  Available steps include: `:conform`, `:prepare`, `:validate`, `:execute`, and any
  extension-injected steps.

  ## Attaching Handlers

  You can attach telemetry handlers to observe operation execution:

      :telemetry.attach_many(
        "my-operations-handler",
        [
          [:my_app, :commands, :step, :start],
          [:my_app, :commands, :step, :stop]
        ],
        &MyApp.TelemetryHandler.handle_event/4,
        %{}
      )

  """

  @behaviour Drops.Operations.Extension

  @impl true
  def enabled?(opts) do
    telemetry_opt = Keyword.get(opts, :telemetry, false)
    telemetry_opt == true or (is_list(telemetry_opt) and telemetry_opt != [])
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
    # Parse telemetry configuration to see if :execute step should be monitored
    telemetry_config = parse_telemetry_config(opts)

    if :execute in get_monitored_steps(telemetry_config, [:execute]) do
      # Inject telemetry-aware execute functions
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
        # No telemetry for execute step
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
    if :execute in monitored_steps do
      Map.put(extended_uow, :execute_telemetry_config, %{
        operation: operation_module,
        operation_type: operation_type,
        telemetry_prefix: telemetry_config.prefix
      })
    else
      extended_uow
    end
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

  defp parse_telemetry_config(opts) do
    telemetry_opt = Keyword.get(opts, :telemetry, false)
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, [:drops, :operations])

    case telemetry_opt do
      true ->
        # Legacy boolean format - use telemetry_prefix option
        %{prefix: telemetry_prefix, steps: :all}

      config when is_list(config) ->
        # New configuration format
        prefix = Keyword.get(config, :prefix, telemetry_prefix)
        steps = Keyword.get(config, :steps, :all)
        %{prefix: prefix, steps: steps}

      _ ->
        # Fallback (shouldn't happen if enabled?/1 is correct)
        %{prefix: telemetry_prefix, steps: :all}
    end
  end

  defp get_monitored_steps(%{steps: :all}, available_steps), do: available_steps

  defp get_monitored_steps(%{steps: steps}, available_steps) when is_list(steps) do
    # Only include steps that are both requested and available
    Enum.filter(steps, &(&1 in available_steps))
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
