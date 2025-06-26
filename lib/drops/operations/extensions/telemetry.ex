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
  using the `:telemetry_prefix` option.

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

  ## Customizing Event Names

  You can customize the telemetry event prefix using the `:telemetry_prefix` option:

      defmodule MyApp.Operations do
        use Drops.Operations, telemetry: true, telemetry_prefix: [:my_app, :operations]
      end

  This will emit events like `[:my_app, :operations, :step, :start]` instead of the default
  `[:drops, :operations, :step, :start]`.

  ## Attaching Handlers

  You can attach telemetry handlers to observe operation execution:

      :telemetry.attach_many(
        "my-operations-handler",
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
    Keyword.get(opts, :telemetry, false) == true
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
  def extend_operation_definition(_opts) do
    quote do
      # No additional compile-time code needed
    end
  end

  @impl true
  def extend_unit_of_work(uow, opts) do
    # Get operation metadata for telemetry events
    operation_module = uow.operation_module
    operation_type = Keyword.get(opts, :type, :unknown)
    telemetry_prefix = Keyword.get(opts, :telemetry_prefix, [:drops, :operations])

    # Register telemetry callbacks for all steps
    # Use around callbacks only to get accurate timing and handle exceptions
    steps = Map.keys(uow.steps)

    Enum.reduce(steps, uow, fn step, acc_uow ->
      acc_uow
      |> Drops.Operations.UnitOfWork.register_around_callback(
        step,
        __MODULE__,
        :emit_around_event,
        %{
          operation: operation_module,
          operation_type: operation_type,
          telemetry_prefix: telemetry_prefix
        }
      )
    end)
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
end
