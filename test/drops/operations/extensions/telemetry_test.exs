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

  describe "operation-level telemetry (default behavior)" do
    setup do
      # Capture operation-level telemetry events
      ref = make_ref()

      handler_id = "test-operation-telemetry-handler-#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        [
          [:drops, :operations, :operation, :start],
          [:drops, :operations, :operation, :stop]
        ],
        &TestTelemetryHandler.handle_event/4,
        %{ref: ref, pid: self()}
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, events_ref: ref}
    end

    operation name: :operation_level_success, type: :command, telemetry: true do
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

    test "emits operation-level telemetry events for successful operation", %{
      operation_level_success: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{name: "Alice"})

      # Should receive exactly 2 events: start and stop
      events = collect_events(ref, 2)

      assert length(events) == 2

      # Verify event structure
      [
        {start_event, start_measurements, start_metadata},
        {stop_event, stop_measurements, stop_metadata}
      ] = events

      # Start event
      assert start_event == [:drops, :operations, :operation, :start]
      assert Map.has_key?(start_measurements, :system_time)
      assert Map.has_key?(start_metadata, :operation)
      assert Map.has_key?(start_metadata, :operation_type)
      assert start_metadata.operation_type == :command
      refute Map.has_key?(start_metadata, :step)

      # Stop event
      assert stop_event == [:drops, :operations, :operation, :stop]
      assert Map.has_key?(stop_measurements, :duration)
      assert Map.has_key?(stop_metadata, :operation)
      assert Map.has_key?(stop_metadata, :operation_type)
      assert stop_metadata.operation_type == :command
      refute Map.has_key?(stop_metadata, :step)
    end

    operation name: :operation_level_validation_error, type: :command, telemetry: true do
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

    test "emits operation-level telemetry events for operations with validation errors",
         %{
           operation_level_validation_error: operation,
           events_ref: ref
         } do
      # This should return an error due to validation failure
      {:error, _failure} = operation.call(%{name: "error"})

      # Should still receive exactly 2 events: start and stop (even for failed operations)
      events = collect_events(ref, 2)

      assert length(events) == 2

      # Verify all events have the correct structure
      for {event, measurements, metadata} <- events do
        assert event in [
                 [:drops, :operations, :operation, :start],
                 [:drops, :operations, :operation, :stop]
               ]

        assert Map.has_key?(metadata, :operation)
        assert Map.has_key?(metadata, :operation_type)
        assert metadata.operation_type == :command
        refute Map.has_key?(metadata, :step)

        case List.last(event) do
          :start -> assert Map.has_key?(measurements, :system_time)
          :stop -> assert Map.has_key?(measurements, :duration)
        end
      end
    end

    operation name: :operation_level_query, type: :query, telemetry: true do
      @impl true
      def execute(%{params: _params}) do
        {:ok, %{data: "query result"}}
      end
    end

    test "includes correct operation type in metadata for queries", %{
      operation_level_query: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{})

      # Should receive exactly 2 events: start and stop
      events = collect_events(ref, 2)

      assert length(events) == 2

      for {_event, _measurements, metadata} <- events do
        assert metadata.operation_type == :query
      end
    end

    operation name: :operation_level_custom_prefix,
              type: :command,
              telemetry: [prefix: [:my_app, :operations]] do
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

    test "supports custom prefix for operation-level events", %{
      operation_level_custom_prefix: operation,
      events_ref: _ref
    } do
      # Need to set up a separate handler for custom prefix
      custom_ref = make_ref()

      custom_handler_id =
        "test-custom-operation-telemetry-handler-#{System.unique_integer()}"

      :telemetry.attach_many(
        custom_handler_id,
        [
          [:my_app, :operations, :operation, :start],
          [:my_app, :operations, :operation, :stop]
        ],
        &TestTelemetryHandler.handle_event/4,
        %{ref: custom_ref, pid: self()}
      )

      {:ok, _result} = operation.call(%{name: "Alice"})

      # Should receive exactly 2 events with custom prefix
      events = collect_events(custom_ref, 2)

      assert length(events) == 2

      # Verify all events use the custom prefix
      for {event, _measurements, _metadata} <- events do
        assert event in [
                 [:my_app, :operations, :operation, :start],
                 [:my_app, :operations, :operation, :stop]
               ]
      end

      :telemetry.detach(custom_handler_id)
    end

    operation name: :boolean_format_operation, type: :command, telemetry: true do
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

    test "boolean format now defaults to operation-level events", %{
      boolean_format_operation: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{name: "Alice"})

      # Should receive exactly 2 operation-level events (not step-level)
      events = collect_events(ref, 2)

      assert length(events) == 2

      # Verify all events are operation-level
      for {event, measurements, metadata} <- events do
        assert event in [
                 [:drops, :operations, :operation, :start],
                 [:drops, :operations, :operation, :stop]
               ]

        assert Map.has_key?(metadata, :operation)
        assert Map.has_key?(metadata, :operation_type)
        refute Map.has_key?(metadata, :step)

        case List.last(event) do
          :start -> assert Map.has_key?(measurements, :system_time)
          :stop -> assert Map.has_key?(measurements, :duration)
        end
      end
    end
  end

  describe "both operation and step-level telemetry" do
    setup do
      # Capture both operation and step-level telemetry events
      ref = make_ref()

      handler_id = "test-both-telemetry-handler-#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        [
          [:drops, :operations, :operation, :start],
          [:drops, :operations, :operation, :stop],
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

    operation name: :both_levels_operation,
              type: :command,
              telemetry: [level: :both] do
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

    test "emits both operation and step-level telemetry events", %{
      both_levels_operation: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{name: "Alice"})

      # Should receive operation events (2) + step events (6 for prepare/validate/conform)
      events = collect_events(ref, 8)

      assert length(events) >= 8

      # Separate operation and step events
      operation_events =
        Enum.filter(events, fn {event, _, _} ->
          event |> Enum.at(2) == :operation
        end)

      step_events =
        Enum.filter(events, fn {event, _, _} ->
          event |> Enum.at(2) == :step
        end)

      # Should have exactly 2 operation events
      assert length(operation_events) == 2

      # Should have at least 6 step events (prepare, validate, conform - start/stop each)
      assert length(step_events) >= 6

      # Verify operation events structure
      for {event, measurements, metadata} <- operation_events do
        assert event in [
                 [:drops, :operations, :operation, :start],
                 [:drops, :operations, :operation, :stop]
               ]

        assert Map.has_key?(metadata, :operation)
        assert Map.has_key?(metadata, :operation_type)
        refute Map.has_key?(metadata, :step)

        case List.last(event) do
          :start -> assert Map.has_key?(measurements, :system_time)
          :stop -> assert Map.has_key?(measurements, :duration)
        end
      end

      # Verify step events structure
      for {event, measurements, metadata} <- step_events do
        assert event in [
                 [:drops, :operations, :step, :start],
                 [:drops, :operations, :step, :stop]
               ]

        assert Map.has_key?(metadata, :operation)
        assert Map.has_key?(metadata, :operation_type)
        assert Map.has_key?(metadata, :step)

        case List.last(event) do
          :start -> assert Map.has_key?(measurements, :system_time)
          :stop -> assert Map.has_key?(measurements, :duration)
        end
      end
    end
  end

  describe "step-level telemetry" do
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

    operation name: :success_operation, type: :command, telemetry: :steps do
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

    operation name: :validation_error_operation, type: :command, telemetry: :steps do
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

    operation type: :query, telemetry: :steps do
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
              telemetry: :steps,
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

  describe "new telemetry configuration format" do
    setup do
      # Capture telemetry events with custom prefix
      ref = make_ref()

      handler_id = "test-new-config-telemetry-handler-#{System.unique_integer()}"

      :telemetry.attach_many(
        handler_id,
        [
          [:my_app, :commands, :step, :start],
          [:my_app, :commands, :step, :stop]
        ],
        &TestTelemetryHandler.handle_event/4,
        %{ref: ref, pid: self()}
      )

      on_exit(fn ->
        :telemetry.detach(handler_id)
      end)

      {:ok, events_ref: ref}
    end

    operation name: :new_config_operation,
              type: :command,
              telemetry: [level: :steps, prefix: [:my_app, :commands], steps: [:execute]] do
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

    test "emits telemetry events only for specified steps with custom prefix", %{
      new_config_operation: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{name: "Alice"})

      # Should only receive events for the :execute step (start + stop)
      events = collect_events(ref, 2)

      assert length(events) == 2

      # Verify all events use the custom prefix and are for the execute step
      for {event, _measurements, metadata} <- events do
        assert event in [
                 [:my_app, :commands, :step, :start],
                 [:my_app, :commands, :step, :stop]
               ]

        assert metadata.step == :execute
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

      assert length(start_events) == 1
      assert length(stop_events) == 1
    end

    operation name: :multiple_steps_operation,
              type: :command,
              telemetry: [
                level: :steps,
                prefix: [:my_app, :commands],
                steps: [:prepare, :validate]
              ] do
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

    test "emits telemetry events for multiple specified steps", %{
      multiple_steps_operation: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{name: "Alice"})

      # Should receive events for :prepare and :validate steps (start + stop each)
      events = collect_events(ref, 4)

      assert length(events) == 4

      # Verify all events use the custom prefix
      for {event, _measurements, _metadata} <- events do
        assert event in [
                 [:my_app, :commands, :step, :start],
                 [:my_app, :commands, :step, :stop]
               ]
      end

      # Verify we have events for the correct steps
      steps = Enum.map(events, fn {_, _, metadata} -> metadata.step end) |> Enum.uniq()
      assert :prepare in steps
      assert :validate in steps
      refute :execute in steps
    end
  end

  describe "backward compatibility" do
    setup do
      # Capture telemetry events with default prefix
      ref = make_ref()

      handler_id = "test-backward-compat-telemetry-handler-#{System.unique_integer()}"

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

    operation name: :backward_compat_operation,
              type: :command,
              telemetry: :steps do
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

    test "steps atom format enables step-level events for all steps", %{
      backward_compat_operation: operation,
      events_ref: ref
    } do
      {:ok, _result} = operation.call(%{name: "Alice"})

      # Should receive events for all steps (conform, prepare, validate)
      events = collect_events(ref, 6)

      # Should have at least 2 start and 2 stop events (prepare and validate)
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

      # Verify all events use the default prefix
      for {event, _measurements, _metadata} <- events do
        assert event in [
                 [:drops, :operations, :step, :start],
                 [:drops, :operations, :step, :stop]
               ]
      end
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
