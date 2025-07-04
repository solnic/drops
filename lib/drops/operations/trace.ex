defmodule Drops.Operations.Trace do
  @moduledoc """
  Trace struct for tracking operation execution state, flow, and timing.

  The Trace captures comprehensive information about the processing flow:
  - Which steps were processed and in what order
  - What each step received as input (context)
  - What each step returned as output (result)
  - How long each step took to process
  - Overall operation timing and metadata

  The Trace follows Oban's telemetry patterns for timing measurement,
  using `System.monotonic_time()` for duration calculation and `System.system_time()`
  for start events. This provides accurate timing information without relying
  on the Process dictionary.

  ## Fields

  - `:operation` - The operation module being processed
  - `:start_mono` - Monotonic time when processing started (for duration calculation)
  - `:start_time` - System time when processing started (for telemetry events)
  - `:current_step` - The currently executing step (nil if no step is active)
  - `:step_timings` - Map of step names to timing and execution information
  - `:metadata` - Additional metadata that can be stored by extensions

  ## Step Timing Structure

  Each entry in `:step_timings` contains:
  - `:start_mono` - Monotonic time when step started
  - `:start_time` - System time when step started
  - `:duration` - Duration in native time units (nil if step hasn't finished)
  - `:result` - Step result (nil if step hasn't finished)

  ## Usage

  The Trace is typically created and managed by the UnitOfWork:

      trace = Trace.new(MyOperation)
      trace = Trace.start_step(trace, :prepare)
      trace = Trace.finish_step(trace, :prepare, {:ok, result})
      duration = Trace.step_duration(trace, :prepare)

  Extensions can access and modify the trace through UnitOfWork callbacks.
  """

  @type step_timing :: %{
          start_mono: integer(),
          start_time: integer(),
          duration: integer() | nil,
          result: any() | nil
        }

  @type t :: %__MODULE__{
          operation: module(),
          start_mono: integer(),
          start_time: integer(),
          current_step: atom() | nil,
          step_timings: %{atom() => step_timing()},
          metadata: map()
        }

  @enforce_keys [:operation, :start_mono, :start_time]
  defstruct [
    :operation,
    :start_mono,
    :start_time,
    :current_step,
    step_timings: %{},
    metadata: %{}
  ]

  @doc """
  Creates a new Trace for the given operation.

  ## Parameters

  - `operation` - The operation module being processed

  ## Returns

  Returns a new Trace struct with timing information initialized.

  ## Examples

      trace = Trace.new(MyOperation)
      # => %Trace{operation: MyOperation, start_mono: ..., start_time: ...}
  """
  @spec new(module()) :: t()
  def new(operation) when is_atom(operation) do
    %__MODULE__{
      operation: operation,
      start_mono: System.monotonic_time(),
      start_time: System.system_time()
    }
  end

  @doc """
  Marks the start of a step in the trace.

  ## Parameters

  - `trace` - The trace struct
  - `step` - The step name being started

  ## Returns

  Returns the updated trace with step timing information.

  ## Examples

      trace = Trace.start_step(trace, :prepare)
  """
  @spec start_step(t(), atom()) :: t()
  def start_step(%__MODULE__{} = trace, step) when is_atom(step) do
    step_timing = %{
      start_mono: System.monotonic_time(),
      start_time: System.system_time(),
      duration: nil,
      result: nil
    }

    %{
      trace
      | current_step: step,
        step_timings: Map.put(trace.step_timings, step, step_timing)
    }
  end

  @doc """
  Marks the completion of a step in the trace.

  ## Parameters

  - `trace` - The trace struct
  - `step` - The step name being finished
  - `result` - The result of the step execution

  ## Returns

  Returns the updated trace with step completion information.

  ## Examples

      trace = Trace.finish_step(trace, :prepare, {:ok, result})
  """
  @spec finish_step(t(), atom(), any()) :: t()
  def finish_step(%__MODULE__{} = trace, step, result) when is_atom(step) do
    case Map.get(trace.step_timings, step) do
      nil ->
        # Step wasn't started, just return trace unchanged
        trace

      step_timing ->
        end_mono = System.monotonic_time()
        duration = end_mono - step_timing.start_mono

        updated_timing = %{step_timing | duration: duration, result: result}

        %{
          trace
          | current_step: nil,
            step_timings: Map.put(trace.step_timings, step, updated_timing)
        }
    end
  end

  @doc """
  Gets the total duration of the operation processing.

  ## Parameters

  - `trace` - The trace struct

  ## Returns

  Returns the duration in native time units, or nil if processing hasn't finished.

  ## Examples

      duration = Trace.total_duration(trace)
  """
  @spec total_duration(t()) :: integer() | nil
  def total_duration(%__MODULE__{} = trace) do
    if trace.current_step == nil and not Enum.empty?(trace.step_timings) do
      # Calculate total duration from first step start to last step finish
      step_timings = Map.values(trace.step_timings)

      # Find the earliest start time and latest end time
      earliest_start =
        step_timings
        |> Enum.map(& &1.start_mono)
        |> Enum.min()

      latest_end =
        step_timings
        |> Enum.filter(fn timing -> not is_nil(timing.duration) end)
        |> Enum.map(fn timing -> timing.start_mono + timing.duration end)
        |> Enum.max()

      latest_end - earliest_start
    else
      nil
    end
  end

  @doc """
  Gets the duration of a specific step.

  ## Parameters

  - `trace` - The trace struct
  - `step` - The step name

  ## Returns

  Returns the step duration in native time units, or nil if step hasn't finished.

  ## Examples

      duration = Trace.step_duration(trace, :prepare)
  """
  @spec step_duration(t(), atom()) :: integer() | nil
  def step_duration(%__MODULE__{} = trace, step) when is_atom(step) do
    case Map.get(trace.step_timings, step) do
      %{duration: duration} -> duration
      _ -> nil
    end
  end

  @doc """
  Adds metadata to the trace.

  ## Parameters

  - `trace` - The trace struct
  - `key` - The metadata key
  - `value` - The metadata value

  ## Returns

  Returns the updated trace with the new metadata.

  ## Examples

      trace = Trace.put_metadata(trace, :telemetry_enabled, true)
  """
  @spec put_metadata(t(), any(), any()) :: t()
  def put_metadata(%__MODULE__{} = trace, key, value) do
    %{trace | metadata: Map.put(trace.metadata, key, value)}
  end

  @doc """
  Gets metadata from the trace.

  ## Parameters

  - `trace` - The trace struct
  - `key` - The metadata key
  - `default` - The default value if key is not found

  ## Returns

  Returns the metadata value or the default.

  ## Examples

      enabled = Trace.get_metadata(trace, :telemetry_enabled, false)
  """
  @spec get_metadata(t(), any(), any()) :: any()
  def get_metadata(%__MODULE__{} = trace, key, default \\ nil) do
    Map.get(trace.metadata, key, default)
  end
end
