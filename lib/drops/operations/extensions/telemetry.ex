defmodule Drops.Operations.Extensions.Telemetry do
  @moduledoc """
  Telemetry extension for Operations framework.

  This extension provides telemetry instrumentation for Operations steps,
  allowing you to monitor and observe the execution of your operations.

  ## Features

  - Automatic operation-level telemetry (instruments first and last steps)
  - Configurable step-level instrumentation
  - Integration with Elixir's :telemetry library
  - Metadata includes operation module, step name, and execution context

  ## Usage

  ### Default Behavior

  Enable telemetry with default behavior (instruments operation start/stop using first/last steps):

      defmodule CreateUser do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  ### Custom Step Configuration

  Instrument specific steps only:

      defmodule CreateUser do
        use Drops.Operations.Command, telemetry: [steps: [:validate, :execute]]

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  Instrument all steps:

      defmodule CreateUser do
        use Drops.Operations.Command, telemetry: [steps: :all]

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  ### Custom Event Identifier

  Configure a custom identifier for telemetry events (replaces `:drops` in event names):

      defmodule CreateUser do
        use Drops.Operations.Command, telemetry: [identifier: :my_app]

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  This will emit events like `[:my_app, :operations, :operation, :start]` instead of `[:drops, :operations, :operation, :start]`.

  ### Combined Configuration

  You can combine custom identifier with step configuration:

      defmodule CreateUser do
        use Drops.Operations.Command, telemetry: [identifier: :my_app, steps: [:validate, :execute]]

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  ### Step Error Instrumentation

  You can instrument step error events separately from regular step events using `telemetry_step_errors`:

      defmodule CreateUser do
        use Drops.Operations.Command,
          telemetry: true,
          telemetry_step_errors: :all

        steps do
          def validate(%{params: params}) do
            # validation logic that might fail
            {:error, "validation failed"}
          end

          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  This will:
  - Instrument operation boundaries (start/stop events) via `telemetry: true`
  - Instrument error events for all steps when they return `{:error, reason}` via `telemetry_step_errors: :all`

  You can also specify specific steps for error instrumentation:

      defmodule CreateUser do
        use Drops.Operations.Command,
          telemetry: true,
          telemetry_step_errors: [:validate, :execute]
      end

  The `telemetry_step_errors` configuration uses the same identifier as the main `telemetry` configuration.

  ## Telemetry Events

  The extension emits the following telemetry events:

  ### Operation-Level Events (when `telemetry: true`)

  - `[<identifier>, :operation, :start]` - Emitted before the first step executes
  - `[<identifier>, :operation, :stop]` - Emitted after the last step completes successfully
  - `[<identifier>, :operation, :exception]` - Emitted when the last step fails

  ### Step-Level Events (when `telemetry: [steps: [...]]`)

  - `[<identifier>, :operation, :step, :start]` - Emitted before a specific step executes
  - `[<identifier>, :operation, :step, :stop]` - Emitted after a specific step completes successfully
  - `[<identifier>, :operation, :step, :exception]` - Emitted when a specific step fails

  ### Step Error Events (when `telemetry_step_errors: [...]`)

  - `[<identifier>, :operation, :step, :exception]` - Emitted when a step returns `{:error, reason}`

  This is useful for capturing step failures without the overhead of instrumenting all step events.
  The error events include the same metadata as regular step exception events but are only emitted
  for error returns, not actual exceptions.

  Where `<identifier>` defaults to `:drops` but can be customized using the `:identifier` option.

  ### Event Metadata

  All events include the following metadata:

  - `:operation` - The operation module name
  - `:step` - The actual step name (atom) that was instrumented
  - `:context` - The execution context (map)

  ### Event Measurements

  - `:start` events include `:system_time` (system time when step started)
  - `:stop` events include `:duration` (step execution time in native units)
  - `:exception` events include `:duration` and `:kind`, `:reason`, `:stacktrace`

  ## Example Usage with Telemetry Handlers

      # In your application startup (using default :drops identifier)
      :telemetry.attach_many(
        "operations-telemetry",
        [
          [:drops, :operation, :start],
          [:drops, :operation, :stop],
          [:drops, :operation, :exception],
          [:drops, :operation, :step, :start],
          [:drops, :operation, :step, :stop],
          [:drops, :operation, :step, :exception]
        ],
        &MyApp.TelemetryHandler.handle_event/4,
        %{}
      )

      # Or with custom identifier
      :telemetry.attach_many(
        "my-app-operations-telemetry",
        [
          [:my_app, :operation, :start],
          [:my_app, :operation, :stop],
          [:my_app, :operation, :exception],
          [:my_app, :operation, :step, :start],
          [:my_app, :operation, :step, :stop],
          [:my_app, :operation, :step, :exception]
        ],
        &MyApp.TelemetryHandler.handle_event/4,
        %{}
      )

      defmodule MyApp.TelemetryHandler do
        require Logger

        def handle_event([_identifier, :operation, :start], measurements, metadata, _config) do
          Logger.info("Starting operation \#{metadata.operation} with step \#{metadata.step}")
        end

        def handle_event([_identifier, :operation, :stop], measurements, metadata, _config) do
          duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
          Logger.info("Completed operation \#{metadata.operation} in \#{duration_ms}ms")
        end

        def handle_event([_identifier, :operation, :step, :start], measurements, metadata, _config) do
          Logger.info("Starting step \#{metadata.step} in \#{metadata.operation}")
        end

        def handle_event([_identifier, :operation, :step, :stop], measurements, metadata, _config) do
          duration_ms = System.convert_time_unit(measurements.duration, :native, :millisecond)
          Logger.info("Completed step \#{metadata.step} in \#{duration_ms}ms")
        end

        def handle_event([_identifier, :operation, :exception], measurements, metadata, _config) do
          Logger.error("Failed in \#{metadata.operation}: \#{inspect(metadata.reason)}")
        end

        def handle_event([_identifier, :operation, :step, :exception], measurements, metadata, _config) do
          Logger.error("Failed step \#{metadata.step} in \#{metadata.operation}: \#{inspect(metadata.reason)}")
        end
      end
  """
  use Drops.Operations.Extension

  @depends_on [Drops.Operations.Extensions.Command, Drops.Operations.Extensions.Params]

  @impl true
  @spec enable?(keyword()) :: boolean()
  def enable?(opts) do
    case opts[:telemetry] do
      false -> false
      nil -> opts[:debug] == true
      _ -> true
    end
  end

  @impl true
  @spec default_opts(keyword()) :: keyword()
  def default_opts(_opts) do
    []
  end

  @impl true
  @spec unit_of_work(Drops.Operations.UnitOfWork.t(), keyword()) ::
          Drops.Operations.UnitOfWork.t()
  def unit_of_work(uow, opts) do
    telemetry_config = Keyword.get(opts, :telemetry, false)
    telemetry_step_errors = Keyword.get(opts, :telemetry_step_errors, false)

    uow =
      case telemetry_config do
        false ->
          uow

        true ->
          # Default behavior: instrument first and last steps for operation boundaries
          identifier = :drops
          instrument_operation_boundaries(uow, identifier)

        config when is_list(config) ->
          # Custom configuration with specific steps and/or identifier
          identifier = Keyword.get(config, :identifier, :drops)
          steps_to_instrument = Keyword.get(config, :steps, [])

          cond do
            steps_to_instrument == [] ->
              # No specific steps configured, use operation boundaries
              instrument_operation_boundaries(uow, identifier)

            steps_to_instrument == :all ->
              # Instrument all available steps using step_order
              all_steps = uow.step_order
              instrument_specific_steps(uow, all_steps, identifier)

            true ->
              # Instrument specific steps
              instrument_specific_steps(uow, steps_to_instrument, identifier)
          end
      end

    # Handle step error instrumentation separately
    case telemetry_step_errors do
      false ->
        uow

      :all ->
        # Instrument error callbacks for all steps
        # Use the same identifier as the main telemetry configuration
        identifier =
          case telemetry_config do
            config when is_list(config) -> Keyword.get(config, :identifier, :drops)
            _ -> :drops
          end

        instrument_step_errors(uow, uow.step_order, identifier)

      steps when is_list(steps) ->
        # Instrument error callbacks for specific steps
        # Use the same identifier as the main telemetry configuration
        identifier =
          case telemetry_config do
            config when is_list(config) -> Keyword.get(config, :identifier, :drops)
            _ -> :drops
          end

        instrument_step_errors(uow, steps, identifier)
    end
  end

  defp instrument_operation_boundaries(uow, identifier) do
    case uow.step_order do
      [] ->
        uow

      [first_step | _] ->
        uow
        # Instrument first step for operation start (using actual step name)
        |> register_before_callback(
          first_step,
          __MODULE__,
          :emit_operation_start,
          {first_step, identifier}
        )
        # Instrument all steps for operation stop to capture failures at any step
        |> instrument_operation_stop_for_all_steps(identifier)
    end
  end

  defp instrument_specific_steps(uow, step_events, identifier) do
    Enum.reduce(step_events, uow, fn step, acc_uow ->
      # Only instrument if the step exists in the pipeline
      if Map.has_key?(acc_uow.steps, step) do
        acc_uow
        |> register_before_callback(
          step,
          __MODULE__,
          :emit_step_start,
          {step, identifier}
        )
        |> register_after_callback(step, __MODULE__, :emit_step_stop, {step, identifier})
      else
        acc_uow
      end
    end)
  end

  defp instrument_operation_stop_for_all_steps(uow, identifier) do
    Enum.reduce(uow.step_order, uow, fn step, acc_uow ->
      register_after_callback(
        acc_uow,
        step,
        __MODULE__,
        :emit_operation_stop,
        {step, identifier}
      )
    end)
  end

  defp instrument_step_errors(uow, step_events, identifier) do
    Enum.reduce(step_events, uow, fn step, acc_uow ->
      # Only instrument if the step exists in the pipeline
      if Map.has_key?(acc_uow.steps, step) do
        register_after_callback(
          acc_uow,
          step,
          __MODULE__,
          :emit_step_error,
          {step, identifier}
        )
      else
        acc_uow
      end
    end)
  end

  @doc false
  def emit_operation_start(operation_module, _step, context, config) do
    {actual_step, identifier} = config.original_config
    start_time = config.trace.start_time

    :telemetry.execute(
      [identifier, :operation, :start],
      %{system_time: start_time},
      %{operation: operation_module, step: actual_step, context: context}
    )

    :ok
  end

  @doc false
  def emit_operation_stop(operation_module, step, context, result, config) do
    {actual_step, identifier} = config.original_config
    duration = Drops.Operations.Trace.total_duration(config.trace) || 0
    current_context = extract_current_context(context, result, actual_step)

    case result do
      {:ok, _} ->
        # Only emit operation stop event if this is the last step
        if is_last_step?(operation_module, step) do
          :telemetry.execute(
            [identifier, :operation, :stop],
            %{duration: duration},
            %{operation: operation_module, step: actual_step, context: current_context}
          )
        end

      {:error, reason} ->
        # Always emit operation exception event when any step fails
        :telemetry.execute(
          [identifier, :operation, :exception],
          %{duration: duration},
          %{
            operation: operation_module,
            step: actual_step,
            context: current_context,
            kind: :error,
            reason: reason,
            stacktrace: []
          }
        )
    end

    :ok
  end

  defp is_last_step?(operation_module, step) do
    List.last(operation_module.__unit_of_work__().step_order) == step
  end

  # Extracts the most current context from step results for telemetry
  # This ensures telemetry events show the actual state after step execution
  defp extract_current_context(input_context, result, _step) do
    case result do
      {:ok, new_context} when is_map(new_context) ->
        # For successful steps, use the updated context
        new_context

      {:error, %Ecto.Changeset{} = changeset} ->
        # For validation failures with changesets, use context with the invalid changeset
        # This shows the actual validation errors instead of the pre-validation state
        Map.put(input_context, :changeset, changeset)

      {:error, _reason} ->
        # For other errors, use the original input context
        input_context
    end
  end

  @doc false
  def emit_step_start(operation_module, _step, context, config) do
    {actual_step, identifier} = config.original_config

    start_time = config.trace.step_timings[actual_step][:start_time]

    :telemetry.execute(
      [identifier, :operation, :step, :start],
      %{system_time: start_time},
      %{operation: operation_module, step: actual_step, context: context}
    )

    :ok
  end

  @doc false
  def emit_step_stop(operation_module, _step, context, result, config) do
    {actual_step, identifier} = config.original_config
    duration = config.trace.step_timings[actual_step][:duration]
    current_context = extract_current_context(context, result, actual_step)

    case result do
      {:ok, _} ->
        :telemetry.execute(
          [identifier, :operation, :step, :stop],
          %{duration: duration},
          %{operation: operation_module, step: actual_step, context: current_context}
        )

      {:error, reason} ->
        :telemetry.execute(
          [identifier, :operation, :step, :exception],
          %{duration: duration},
          %{
            operation: operation_module,
            step: actual_step,
            context: current_context,
            kind: :error,
            reason: reason,
            stacktrace: []
          }
        )
    end

    :ok
  end

  @doc false
  def emit_step_error(operation_module, _step, context, result, config) do
    {actual_step, identifier} = config.original_config
    duration = config.trace.step_timings[actual_step][:duration]
    current_context = extract_current_context(context, result, actual_step)

    case result do
      {:error, reason} ->
        :telemetry.execute(
          [identifier, :operation, :step, :exception],
          %{duration: duration},
          %{
            operation: operation_module,
            step: actual_step,
            context: current_context,
            kind: :error,
            reason: reason,
            stacktrace: []
          }
        )

      _ ->
        # Not an error, do nothing
        :ok
    end

    :ok
  end
end
