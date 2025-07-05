defmodule Drops.Operations.TraceTest do
  use ExUnit.Case, async: true

  alias Drops.Operations.Trace

  describe "Trace.new/1" do
    test "creates a new trace with timing information" do
      trace = Trace.new(TestOperation)

      assert trace.operation == TestOperation
      assert is_integer(trace.start_mono)
      assert is_integer(trace.start_time)
      assert trace.current_step == nil
      assert trace.step_timings == %{}
      assert trace.metadata == %{}
    end
  end

  describe "step tracking" do
    test "tracks step start and finish" do
      trace = Trace.new(TestOperation)

      # Start a step
      trace = Trace.start_step(trace, :prepare)
      assert trace.current_step == :prepare
      assert Map.has_key?(trace.step_timings, :prepare)

      step_timing = trace.step_timings[:prepare]
      assert is_integer(step_timing.start_mono)
      assert is_integer(step_timing.start_time)
      assert step_timing.duration == nil
      assert step_timing.result == nil

      # Finish the step
      result = {:ok, "success"}
      trace = Trace.finish_step(trace, :prepare, result)
      assert trace.current_step == nil

      updated_timing = trace.step_timings[:prepare]
      assert is_integer(updated_timing.duration)
      assert updated_timing.result == result
    end

    test "handles multiple steps" do
      trace = Trace.new(TestOperation)

      # Start and finish first step
      trace =
        trace
        |> Trace.start_step(:prepare)
        |> Trace.finish_step(:prepare, {:ok, "prepared"})

      # Start and finish second step
      trace =
        trace
        |> Trace.start_step(:execute)
        |> Trace.finish_step(:execute, {:ok, "executed"})

      assert Map.has_key?(trace.step_timings, :prepare)
      assert Map.has_key?(trace.step_timings, :execute)
      assert trace.step_timings[:prepare].result == {:ok, "prepared"}
      assert trace.step_timings[:execute].result == {:ok, "executed"}
    end
  end

  describe "duration calculations" do
    test "calculates step duration" do
      trace = Trace.new(TestOperation)

      trace =
        trace
        |> Trace.start_step(:prepare)
        |> Trace.finish_step(:prepare, {:ok, "success"})

      duration = Trace.step_duration(trace, :prepare)
      assert is_integer(duration)
      assert duration > 0
    end

    test "returns nil for unfinished step" do
      trace =
        Trace.new(TestOperation)
        |> Trace.start_step(:prepare)

      duration = Trace.step_duration(trace, :prepare)
      assert duration == nil
    end

    test "returns nil for non-existent step" do
      trace = Trace.new(TestOperation)
      duration = Trace.step_duration(trace, :nonexistent)
      assert duration == nil
    end

    test "calculates total duration when operation is complete" do
      trace = Trace.new(TestOperation)
      trace = Trace.start_step(trace, :prepare)
      trace = Trace.finish_step(trace, :prepare, {:ok, "result"})

      duration = Trace.total_duration(trace)
      assert is_integer(duration)
      assert duration > 0
    end

    test "returns nil when operation is still in progress" do
      trace = Trace.new(TestOperation)
      trace = Trace.start_step(trace, :prepare)

      assert Trace.total_duration(trace) == nil
    end

    test "returns consistent duration even when called later" do
      trace = Trace.new(TestOperation)
      trace = Trace.start_step(trace, :prepare)
      trace = Trace.finish_step(trace, :prepare, {:ok, "result"})

      # Get duration immediately after finishing
      duration1 = Trace.total_duration(trace)

      # Simulate some time passing (like telemetry callbacks)
      Process.sleep(10)

      # Duration should be the same, not include the sleep time
      duration2 = Trace.total_duration(trace)

      assert duration1 == duration2
      assert is_integer(duration1)
      assert duration1 > 0
    end

    test "calculates total duration from first step start to last step finish" do
      trace = Trace.new(TestOperation)

      # Start and finish first step
      trace = Trace.start_step(trace, :prepare)
      # Small delay
      Process.sleep(5)
      trace = Trace.finish_step(trace, :prepare, {:ok, "result1"})

      # Start and finish second step
      trace = Trace.start_step(trace, :execute)
      # Small delay
      Process.sleep(5)
      trace = Trace.finish_step(trace, :execute, {:ok, "result2"})

      total_duration = Trace.total_duration(trace)
      prepare_duration = Trace.step_duration(trace, :prepare)
      execute_duration = Trace.step_duration(trace, :execute)

      # Total should be from start of first step to end of last step
      # This should be >= sum of individual steps due to potential gaps
      assert total_duration >= prepare_duration + execute_duration
      assert is_integer(total_duration)
      assert total_duration > 0
    end
  end

  describe "metadata management" do
    test "stores and retrieves metadata" do
      trace =
        Trace.new(TestOperation)
        |> Trace.put_metadata(:telemetry_enabled, true)
        |> Trace.put_metadata(:custom_data, %{key: "value"})

      assert Trace.get_metadata(trace, :telemetry_enabled) == true
      assert Trace.get_metadata(trace, :custom_data) == %{key: "value"}
      assert Trace.get_metadata(trace, :nonexistent) == nil
      assert Trace.get_metadata(trace, :nonexistent, "default") == "default"
    end
  end
end
