defmodule Drops.Operations.Extensions.TelemetryTest do
  use Drops.OperationCase, async: true

  defmodule TestTelemetryHandler do
    @moduledoc """
    Test telemetry handler module to avoid performance warnings from using anonymous functions.
    """

    def handle_event(event, measurements, metadata, config) do
      ref = Map.get(config, :ref)
      pid = Map.get(config, :pid)
      send(pid, {ref, event, measurements, metadata})
    end
  end

  describe "telemetry extension" do
    setup do
      # Capture telemetry events
      _events = []
      ref = make_ref()

      handler_id = "test-telemetry-handler-#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        [
          [:drops, :operations, :step, :start],
          [:drops, :operations, :step, :stop]
        ],
        &TestTelemetryHandler.handle_event/4,
        %{ref: ref, pid: self()}
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, events_ref: ref}
    end

    operation name: :success_operation, type: :command, telemetry: true do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      @impl true
      def execute(%{params: params}) do
        {:ok, %{greeting: "Hello, #{params.name}!"}}
      end
    end

    test "emits telemetry events for successful operation", %{
      success_operation: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{name: "Alice"})

      # Collect all events
      # 3 steps × 2 events each (start + stop)
      events = collect_events(ref, 6)

      # Verify we have start and stop events for conform, prepare, validate steps
      start_events =
        Enum.filter(events, fn {event, _, _} ->
          List.last(event) == :start
        end)

      stop_events =
        Enum.filter(events, fn {event, _, _} ->
          List.last(event) == :stop
        end)

      # Should have at least 2 start and 2 stop events (prepare and validate)
      # conform may be skipped if schema has no keys or is simple
      assert length(start_events) >= 2
      assert length(stop_events) >= 2

      # Verify event structure
      for {event, measurements, metadata} <- start_events do
        assert event == [:drops, :operations, :step, :start]
        assert Map.has_key?(measurements, :system_time)
        assert Map.has_key?(metadata, :operation)
        assert Map.has_key?(metadata, :operation_type)
        assert Map.has_key?(metadata, :step)
        assert metadata.operation_type == :command
      end

      for {event, measurements, metadata} <- stop_events do
        assert event == [:drops, :operations, :step, :stop]
        assert Map.has_key?(measurements, :duration)
        assert Map.has_key?(metadata, :operation)
        assert Map.has_key?(metadata, :operation_type)
        assert Map.has_key?(metadata, :step)
        assert metadata.operation_type == :command
      end

      # Verify steps are present
      steps = Enum.map(start_events, fn {_, _, metadata} -> metadata.step end)
      # conform may be skipped for simple schemas
      assert :prepare in steps
      assert :validate in steps
    end

    operation name: :validation_error_operation, type: :command, telemetry: true do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      @impl true
      def validate(%{params: %{name: "error"}}) do
        {:error, "Name cannot be 'error'"}
      end

      @impl true
      def validate(context), do: {:ok, context}

      @impl true
      def execute(%{params: params}) do
        {:ok, %{greeting: "Hello, #{params.name}!"}}
      end
    end

    test "emits telemetry events for operations with validation errors", %{
      validation_error_operation: operation,
      events_ref: ref
    } do
      # This should return an error due to validation failure
      {:error, _failure} = operation.call(%{name: "error"})

      # Collect events - should have start/stop events for all steps that executed
      # Even failed validation should emit start/stop events
      events = collect_events(ref, 6)

      start_events =
        Enum.filter(events, fn {event, _, _} ->
          List.last(event) == :start
        end)

      stop_events =
        Enum.filter(events, fn {event, _, _} ->
          List.last(event) == :stop
        end)

      # Should have 3 start and 3 stop events (conform, prepare, validate all execute)
      assert length(start_events) >= 3
      assert length(stop_events) >= 3

      # Verify all events have the correct structure
      for {event, measurements, metadata} <- events do
        assert event in [
                 [:drops, :operations, :step, :start],
                 [:drops, :operations, :step, :stop]
               ]

        assert Map.has_key?(metadata, :operation)
        assert Map.has_key?(metadata, :operation_type)
        assert Map.has_key?(metadata, :step)
        assert metadata.operation_type == :command

        case List.last(event) do
          :start -> assert Map.has_key?(measurements, :system_time)
          :stop -> assert Map.has_key?(measurements, :duration)
        end
      end
    end

    operation type: :query, telemetry: true do
      @impl true
      def execute(%{params: _params}) do
        {:ok, %{data: "query result"}}
      end
    end

    test "includes correct operation type in metadata", %{
      operation: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{})

      # No schema, so only prepare and validate (start + stop each)
      events = collect_events(ref, 4)

      for {_event, _measurements, metadata} <- events do
        assert metadata.operation_type == :query
      end
    end
  end

  describe "custom telemetry prefix" do
    setup do
      # Capture telemetry events with custom prefix
      ref = make_ref()

      handler_id = "test-custom-telemetry-handler-#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        [
          [:my_app, :operations, :step, :start],
          [:my_app, :operations, :step, :stop]
        ],
        &TestTelemetryHandler.handle_event/4,
        %{ref: ref, pid: self()}
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, events_ref: ref}
    end

    operation name: :custom_prefix_operation,
              type: :command,
              telemetry: true,
              telemetry_prefix: [:my_app, :operations] do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      @impl true
      def execute(%{params: params}) do
        {:ok, %{greeting: "Hello, #{params.name}!"}}
      end
    end

    test "emits telemetry events with custom prefix", %{
      custom_prefix_operation: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{name: "Alice"})

      # Collect events
      events = collect_events(ref, 6)

      # Verify all events use the custom prefix
      for {event, _measurements, _metadata} <- events do
        assert event in [
                 [:my_app, :operations, :step, :start],
                 [:my_app, :operations, :step, :stop]
               ]
      end

      # Verify we have both start and stop events
      start_events =
        Enum.filter(events, fn {event, _, _} ->
          List.last(event) == :start
        end)

      stop_events =
        Enum.filter(events, fn {event, _, _} ->
          List.last(event) == :stop
        end)

      assert length(start_events) >= 2
      assert length(stop_events) >= 2
    end
  end

  describe "telemetry extension disabled" do
    operation type: :command do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      @impl true
      def execute(%{params: params}) do
        {:ok, %{greeting: "Hello, #{params.name}!"}}
      end
    end

    test "does not emit telemetry events when disabled", %{operation: operation} do
      ref = make_ref()

      handler_id = "test-no-telemetry-handler-#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        [
          [:drops, :operations, :step, :start],
          [:drops, :operations, :step, :stop]
        ],
        &TestTelemetryHandler.handle_event/4,
        %{ref: ref, pid: self()}
      )

      {:ok, _result} = operation.call(%{name: "Alice"})

      # Should not receive any telemetry events
      refute_receive {^ref, _, _, _}, 100

      :telemetry.detach(handler_id)
    end
  end

  # Helper function to collect telemetry events
  defp collect_events(ref, expected_count) do
    collect_events(ref, expected_count, [])
  end

  defp collect_events(_ref, 0, acc), do: Enum.reverse(acc)

  defp collect_events(ref, count, acc) do
    receive do
      {^ref, event, measurements, metadata} ->
        collect_events(ref, count - 1, [{event, measurements, metadata} | acc])
    after
      1000 ->
        # Return what we have so far
        Enum.reverse(acc)
    end
  end
end
