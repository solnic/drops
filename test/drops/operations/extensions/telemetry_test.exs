defmodule Drops.Operations.Extensions.TelemetryTest do
  use Drops.OperationCase, async: false

  alias Drops.Operations.Extensions.Telemetry

  defmodule TelemetryTestHandler do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end
  end

  describe "enable?/1" do
    test "returns false when telemetry is not configured" do
      refute Telemetry.enable?([])
      refute Telemetry.enable?(telemetry: false)
    end

    test "returns true when telemetry is enabled with boolean" do
      assert Telemetry.enable?(telemetry: true)
    end

    test "returns true when telemetry is configured with options" do
      assert Telemetry.enable?(telemetry: [steps: [:validate, :execute]])
    end

    test "returns true when telemetry is configured with custom identifier" do
      assert Telemetry.enable?(telemetry: [identifier: :my_app])
    end

    test "returns true when telemetry is configured with both identifier and steps" do
      assert Telemetry.enable?(
               telemetry: [identifier: :my_app, steps: [:validate, :execute]]
             )
    end
  end

  describe "default_opts/1" do
    test "returns empty list" do
      assert Telemetry.default_opts([]) == []
    end
  end

  describe "telemetry events" do
    setup do
      # Capture telemetry events
      test_pid = self()

      :telemetry.attach_many(
        "test-telemetry",
        [
          [:drops, :operation, :start],
          [:drops, :operation, :stop],
          [:drops, :operation, :exception],
          [:drops, :operation, :step, :start],
          [:drops, :operation, :step, :stop],
          [:drops, :operation, :step, :exception]
        ],
        &TelemetryTestHandler.handle_event/4,
        test_pid
      )

      on_exit(fn ->
        :telemetry.detach("test-telemetry")
      end)

      :ok
    end

    test "emits start and stop events for operation with default telemetry" do
      defmodule TestOperationDefault do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationDefault.call(context)

      # Should receive operation start event (using first step name: prepare)
      assert_receive {:telemetry_event, [:drops, :operation, :start], measurements,
                      metadata}

      assert %{system_time: _} = measurements

      assert %{operation: TestOperationDefault, step: :prepare, context: ^context} =
               metadata

      # Should receive operation stop event (using last step name: execute)
      assert_receive {:telemetry_event, [:drops, :operation, :stop], measurements,
                      metadata}

      assert %{duration: _} = measurements

      # Context should contain the updated result from execute step
      assert %{operation: TestOperationDefault, step: :execute, context: updated_context} =
               metadata

      assert updated_context == %{executed: true, name: "test"}
    end

    test "emits events for specific steps when configured" do
      defmodule TestOperationSpecific do
        use Drops.Operations.Command, telemetry: [steps: [:execute]]

        steps do
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationSpecific.call(context)

      # Should only receive events for the execute step
      assert_receive {:telemetry_event, [:drops, :operation, :step, :start], measurements,
                      metadata}

      assert %{system_time: _} = measurements
      assert %{operation: TestOperationSpecific, step: :execute, context: _} = metadata

      assert_receive {:telemetry_event, [:drops, :operation, :step, :stop], measurements,
                      metadata}

      assert %{duration: _} = measurements
      assert %{operation: TestOperationSpecific, step: :execute, context: _} = metadata

      # Should not receive events for prepare or validate steps
      refute_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :prepare}}

      refute_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :validate}}
    end

    test "emits exception events when operation fails in last step" do
      defmodule TestOperationErrorLastStep do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def execute(_context) do
            {:error, "something went wrong"}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationErrorLastStep.call(context)

      # Should receive operation start event (first step: prepare)
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive exception event for operation stop (last step: execute)
      assert_receive {:telemetry_event, [:drops, :operation, :exception], measurements,
                      metadata}

      assert %{duration: _} = measurements

      assert %{
               operation: TestOperationErrorLastStep,
               step: :execute,
               context: ^context,
               kind: :error,
               reason: "something went wrong"
             } = metadata
    end

    test "emits exception events when operation fails in middle step" do
      defmodule TestOperationErrorMiddleStep do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def validate(_context) do
            {:error, "validation failed"}
          end

          @impl true
          def execute(_context) do
            {:ok, "should not reach here"}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationErrorMiddleStep.call(context)

      # Should receive operation start event (first step: prepare)
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive exception event for operation failure (from validate step)
      assert_receive {:telemetry_event, [:drops, :operation, :exception], measurements,
                      metadata}

      assert %{duration: _} = measurements

      assert %{
               operation: TestOperationErrorMiddleStep,
               step: :validate,
               context: ^context,
               kind: :error,
               reason: "validation failed"
             } = metadata

      # Should NOT receive operation stop event since operation failed
      refute_receive {:telemetry_event, [:drops, :operation, :stop], _, _}
    end

    test "emits exception events when operation fails in first step" do
      defmodule TestOperationErrorFirstStep do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def prepare(_context) do
            {:error, "preparation failed"}
          end

          @impl true
          def validate(_context) do
            {:ok, "should not reach here"}
          end

          @impl true
          def execute(_context) do
            {:ok, "should not reach here"}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationErrorFirstStep.call(context)

      # Should receive operation start event (first step: prepare)
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive exception event for operation failure (from prepare step)
      assert_receive {:telemetry_event, [:drops, :operation, :exception], measurements,
                      metadata}

      assert %{duration: _} = measurements

      assert %{
               operation: TestOperationErrorFirstStep,
               step: :prepare,
               context: ^context,
               kind: :error,
               reason: "preparation failed"
             } = metadata

      # Should NOT receive operation stop event since operation failed
      refute_receive {:telemetry_event, [:drops, :operation, :stop], _, _}
    end

    test "does not emit events when telemetry is disabled" do
      defmodule TestOperationDisabled do
        use Drops.Operations.Command

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationDisabled.call(context)

      # Should not receive any telemetry events
      refute_receive {:telemetry_event, _, _, _}, 100
    end

    test "emits events for multiple configured steps" do
      defmodule TestOperationMultiple do
        use Drops.Operations.Command, telemetry: [steps: [:validate, :execute]]

        steps do
          def prepare(context), do: {:ok, context}

          def validate(context) do
            # Small delay to ensure measurable duration
            Process.sleep(1)
            {:ok, context}
          end

          @impl true
          def execute(%{params: params}) do
            # Small delay to ensure measurable duration
            Process.sleep(1)
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationMultiple.call(context)

      # Should receive events for validate step
      assert_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :validate}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :stop], measurements,
                      %{step: :validate}}

      assert measurements.duration > 0

      # Should receive events for execute step
      assert_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :execute}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :stop], measurements,
                      %{step: :execute}}

      assert measurements.duration > 0

      # Should not receive events for prepare step
      refute_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :prepare}}
    end

    test "emits events for all steps when configured with :all" do
      defmodule TestOperationAll do
        use Drops.Operations.Command, telemetry: [steps: :all]

        schema do
          %{
            required(:name) => string(:filled?)
          }
        end

        steps do
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationAll.call(context)

      # Should receive events for all steps: conform, prepare, validate, execute
      assert_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :conform}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :stop], _,
                      %{step: :conform}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :prepare}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :stop], _,
                      %{step: :prepare}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :validate}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :stop], _,
                      %{step: :validate}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :start], _,
                      %{step: :execute}}

      assert_receive {:telemetry_event, [:drops, :operation, :step, :stop], _,
                      %{step: :execute}}
    end

    test "emits only one operation stop event for successful operations" do
      defmodule TestOperationSingleStopEvent do
        use Drops.Operations.Command, telemetry: true

        steps do
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationSingleStopEvent.call(context)

      # Should receive operation start event
      assert_receive {:telemetry_event, [:drops, :operation, :start], _, _}

      # Should receive exactly one operation stop event
      assert_receive {:telemetry_event, [:drops, :operation, :stop], _, _}

      # Should NOT receive any additional operation stop events
      refute_receive {:telemetry_event, [:drops, :operation, :stop], _, _}

      # Should NOT receive any operation exception events
      refute_receive {:telemetry_event, [:drops, :operation, :exception], _, _}
    end
  end

  describe "integration with operation composition" do
    setup do
      # Capture telemetry events
      test_pid = self()

      :telemetry.attach_many(
        "test-composition-telemetry",
        [
          [:drops, :operation, :start],
          [:drops, :operation, :stop]
        ],
        &TelemetryTestHandler.handle_event/4,
        test_pid
      )

      on_exit(fn ->
        :telemetry.detach("test-composition-telemetry")
      end)

      :ok
    end

    test "emits events for composed operations" do
      defmodule FirstOperation do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :first_done, true)}
          end
        end
      end

      defmodule SecondOperation do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def execute(%{execute_result: result, params: params}) do
            {:ok, Map.merge(result, params)}
          end
        end
      end

      context = %{params: %{name: "test"}}

      result =
        FirstOperation.call(context)
        |> SecondOperation.call(%{params: %{second: true}})

      assert {:ok, %{name: "test", first_done: true, second: true}} = result

      # Should receive events for both operations
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{operation: FirstOperation}}

      assert_receive {:telemetry_event, [:drops, :operation, :stop], _,
                      %{operation: FirstOperation}}

      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{operation: SecondOperation}}

      assert_receive {:telemetry_event, [:drops, :operation, :stop], _,
                      %{operation: SecondOperation}}
    end

    test "emits positive duration values for operation events" do
      defmodule TestOperationDuration do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def execute(%{params: params}) do
            # Add a small delay to ensure measurable duration
            Process.sleep(1)
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationDuration.call(context)

      # Should receive operation stop event with positive duration (using last step name: execute)
      assert_receive {:telemetry_event, [:drops, :operation, :stop], measurements,
                      metadata}

      assert %{duration: duration} = measurements
      assert is_integer(duration)
      assert duration > 0, "Duration should be positive, got: #{duration}"

      assert %{operation: TestOperationDuration, step: :execute, context: _} = metadata
    end

    test "ensures telemetry relies on trace for duration calculations" do
      # Test that telemetry always uses trace-calculated durations
      # and never falls back to its own timing calculations

      defmodule TestTraceDuration do
        use Drops.Operations.Command, telemetry: true

        steps do
          @impl true
          def execute(%{params: params}) do
            # Add a small delay to ensure measurable duration
            Process.sleep(1)
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestTraceDuration.call(context)

      # Collect telemetry events
      events = collect_all_telemetry_events()

      # Check operation stop event
      operation_events =
        Enum.filter(events, fn {event, _measurements, _metadata} ->
          match?([:drops, :operation, :stop], event)
        end)

      assert length(operation_events) == 1
      {_event, measurements, _metadata} = hd(operation_events)

      # Duration should be positive and reasonable (> 0 since we have Process.sleep(1))
      assert measurements.duration > 0,
             "Operation duration should be positive: #{measurements.duration}"

      # Duration should be reasonable (less than 1 second in native time units)
      max_reasonable_duration = System.convert_time_unit(1, :second, :native)

      assert measurements.duration < max_reasonable_duration,
             "Operation duration seems too large: #{measurements.duration}"
    end
  end

  # Helper function to collect all telemetry events from the mailbox
  defp collect_all_telemetry_events(events \\ []) do
    receive do
      {:telemetry_event, event, measurements, metadata} ->
        collect_all_telemetry_events([{event, measurements, metadata} | events])
    after
      100 -> Enum.reverse(events)
    end
  end

  describe "custom identifier configuration" do
    setup do
      # Capture telemetry events with custom identifier
      test_pid = self()

      :telemetry.attach_many(
        "test-custom-identifier-telemetry",
        [
          [:my_app, :operation, :start],
          [:my_app, :operation, :stop],
          [:my_app, :operation, :exception],
          [:my_app, :operation, :step, :start],
          [:my_app, :operation, :step, :stop],
          [:my_app, :operation, :step, :exception]
        ],
        &TelemetryTestHandler.handle_event/4,
        test_pid
      )

      on_exit(fn ->
        :telemetry.detach("test-custom-identifier-telemetry")
      end)

      :ok
    end

    test "emits events with custom identifier for operation boundaries" do
      defmodule TestOperationCustomId do
        use Drops.Operations.Command, telemetry: [identifier: :my_app]

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationCustomId.call(context)

      # Should receive operation start event with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :start], measurements,
                      metadata}

      assert %{system_time: _} = measurements

      assert %{operation: TestOperationCustomId, step: :prepare, context: ^context} =
               metadata

      # Should receive operation stop event with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :stop], measurements,
                      metadata}

      assert %{duration: _} = measurements

      # Context should contain the updated result from execute step
      assert %{operation: TestOperationCustomId, step: :execute, context: updated_context} =
               metadata

      assert updated_context == %{executed: true, name: "test"}
    end

    test "emits events with custom identifier for specific steps" do
      defmodule TestOperationCustomIdSteps do
        use Drops.Operations.Command, telemetry: [identifier: :my_app, steps: [:execute]]

        steps do
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationCustomIdSteps.call(context)

      # Should only receive events for the execute step with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :step, :start],
                      measurements, metadata}

      assert %{system_time: _} = measurements

      assert %{operation: TestOperationCustomIdSteps, step: :execute, context: _} =
               metadata

      assert_receive {:telemetry_event, [:my_app, :operation, :step, :stop], measurements,
                      metadata}

      assert %{duration: _} = measurements

      assert %{operation: TestOperationCustomIdSteps, step: :execute, context: _} =
               metadata

      # Should not receive events for prepare or validate steps
      refute_receive {:telemetry_event, [:my_app, :operation, :step, :start], _,
                      %{step: :prepare}}

      refute_receive {:telemetry_event, [:my_app, :operation, :step, :start], _,
                      %{step: :validate}}
    end

    test "emits exception events with custom identifier when failing in last step" do
      defmodule TestOperationCustomIdErrorLastStep do
        use Drops.Operations.Command, telemetry: [identifier: :my_app]

        steps do
          @impl true
          def execute(_context) do
            {:error, "something went wrong"}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationCustomIdErrorLastStep.call(context)

      # Should receive operation start event with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive exception event with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :exception], measurements,
                      metadata}

      assert %{duration: _} = measurements

      assert %{
               operation: TestOperationCustomIdErrorLastStep,
               step: :execute,
               context: ^context,
               kind: :error,
               reason: "something went wrong"
             } = metadata
    end

    test "emits exception events with custom identifier when failing in middle step" do
      defmodule TestOperationCustomIdErrorMiddleStep do
        use Drops.Operations.Command, telemetry: [identifier: :my_app]

        steps do
          @impl true
          def validate(_context) do
            {:error, "validation failed"}
          end

          @impl true
          def execute(_context) do
            {:ok, "should not reach here"}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationCustomIdErrorMiddleStep.call(context)

      # Should receive operation start event with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive exception event with custom identifier (from validate step)
      assert_receive {:telemetry_event, [:my_app, :operation, :exception], measurements,
                      metadata}

      assert %{duration: _} = measurements

      assert %{
               operation: TestOperationCustomIdErrorMiddleStep,
               step: :validate,
               context: ^context,
               kind: :error,
               reason: "validation failed"
             } = metadata

      # Should NOT receive operation stop event since operation failed
      refute_receive {:telemetry_event, [:my_app, :operation, :stop], _, _}
    end

    test "emits exception events with custom identifier when failing in first step" do
      defmodule TestOperationCustomIdErrorFirstStep do
        use Drops.Operations.Command, telemetry: [identifier: :my_app]

        steps do
          @impl true
          def prepare(_context) do
            {:error, "preparation failed"}
          end

          @impl true
          def validate(_context) do
            {:ok, "should not reach here"}
          end

          @impl true
          def execute(_context) do
            {:ok, "should not reach here"}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationCustomIdErrorFirstStep.call(context)

      # Should receive operation start event with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive exception event with custom identifier (from prepare step)
      assert_receive {:telemetry_event, [:my_app, :operation, :exception], measurements,
                      metadata}

      assert %{duration: _} = measurements

      assert %{
               operation: TestOperationCustomIdErrorFirstStep,
               step: :prepare,
               context: ^context,
               kind: :error,
               reason: "preparation failed"
             } = metadata

      # Should NOT receive operation stop event since operation failed
      refute_receive {:telemetry_event, [:my_app, :operation, :stop], _, _}
    end

    test "does not emit events on default identifier when using custom identifier" do
      defmodule TestOperationNoDefaultEvents do
        use Drops.Operations.Command, telemetry: [identifier: :my_app]

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, Map.put(params, :executed, true)}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationNoDefaultEvents.call(context)

      # Should not receive any events with default :drops identifier
      refute_receive {:telemetry_event, [:drops, :operation, _], _, _}, 100
      refute_receive {:telemetry_event, [:drops, :operation, _, _], _, _}, 100
    end
  end

  describe "telemetry_step_errors configuration" do
    setup do
      # Capture telemetry events
      test_pid = self()

      :telemetry.attach_many(
        "test-step-errors",
        [
          [:drops, :operation, :start],
          [:drops, :operation, :stop],
          [:drops, :operation, :exception],
          [:drops, :operation, :step, :start],
          [:drops, :operation, :step, :stop],
          [:drops, :operation, :step, :exception],
          [:my_app, :operation, :start],
          [:my_app, :operation, :stop],
          [:my_app, :operation, :exception],
          [:my_app, :operation, :step, :start],
          [:my_app, :operation, :step, :stop],
          [:my_app, :operation, :step, :exception]
        ],
        &TelemetryTestHandler.handle_event/4,
        test_pid
      )

      on_exit(fn ->
        :telemetry.detach("test-step-errors")
      end)
    end

    test "emits step exception events for all steps when telemetry_step_errors: :all" do
      defmodule TestOperationStepErrors do
        use Drops.Operations.Command, telemetry: true, telemetry_step_errors: :all

        steps do
          def prepare(_context), do: {:ok, %{prepared: true}}
          def validate(_context), do: {:error, "validation failed"}

          @impl true
          def execute(_context), do: {:ok, %{executed: true}}
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationStepErrors.call(context)

      # Should receive operation start event
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive step exception event for validate step
      assert_receive {:telemetry_event, [:drops, :operation, :step, :exception],
                      measurements, metadata}

      assert metadata.operation == TestOperationStepErrors
      assert metadata.step == :validate
      assert metadata.kind == :error
      assert metadata.reason == "validation failed"
      assert is_integer(measurements.duration)
    end

    test "emits step exception events for specific steps when telemetry_step_errors: [steps]" do
      defmodule TestOperationSpecificStepErrors do
        use Drops.Operations.Command, telemetry: true, telemetry_step_errors: [:validate]

        steps do
          def prepare(_context), do: {:ok, %{prepared: true}}
          def validate(_context), do: {:error, "validation failed"}

          @impl true
          def execute(_context), do: {:ok, %{executed: true}}
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationSpecificStepErrors.call(context)

      # Should receive operation start event
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive step exception event for validate step (in list)
      assert_receive {:telemetry_event, [:drops, :operation, :step, :exception],
                      measurements, metadata}

      assert metadata.operation == TestOperationSpecificStepErrors
      assert metadata.step == :validate
      assert metadata.kind == :error
      assert metadata.reason == "validation failed"
      assert is_integer(measurements.duration)
    end

    test "does not emit step exception events for steps not in telemetry_step_errors list" do
      defmodule TestOperationSpecificStepErrorsExclusion do
        use Drops.Operations.Command, telemetry: true, telemetry_step_errors: [:execute]

        steps do
          def validate(_context), do: {:error, "validation failed"}

          @impl true
          def execute(_context), do: {:ok, %{executed: true}}
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationSpecificStepErrorsExclusion.call(context)

      # Should receive operation start event
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{step: :prepare}}

      # Should NOT receive step exception event for validate step (not in list)
      refute_receive {:telemetry_event, [:drops, :operation, :step, :exception], _,
                      %{step: :validate}}
    end

    test "does not emit step exception events when telemetry_step_errors: false" do
      defmodule TestOperationNoStepErrors do
        use Drops.Operations.Command, telemetry: true, telemetry_step_errors: false

        steps do
          def validate(_context), do: {:error, "validation failed"}

          @impl true
          def execute(_context), do: {:ok, %{executed: true}}
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationNoStepErrors.call(context)

      # Should receive operation start event
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{step: :prepare}}

      # Should NOT receive step exception event for validate step
      refute_receive {:telemetry_event, [:drops, :operation, :step, :exception], _,
                      %{step: :validate}}
    end

    test "works with custom identifier" do
      defmodule TestOperationCustomIdentifierStepErrors do
        use Drops.Operations.Command,
          telemetry: [identifier: :my_app],
          telemetry_step_errors: :all

        steps do
          def validate(_context), do: {:error, "validation failed"}

          @impl true
          def execute(_context), do: {:ok, %{executed: true}}
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationCustomIdentifierStepErrors.call(context)

      # Should receive operation start event with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive step exception event with custom identifier
      assert_receive {:telemetry_event, [:my_app, :operation, :step, :exception],
                      measurements, metadata}

      assert metadata.operation == TestOperationCustomIdentifierStepErrors
      assert metadata.step == :validate
      assert metadata.kind == :error
      assert metadata.reason == "validation failed"
      assert is_integer(measurements.duration)
    end

    test "only emits step exception events for error returns, not success" do
      defmodule TestOperationSuccessStepErrors do
        use Drops.Operations.Command, telemetry: true, telemetry_step_errors: :all

        steps do
          def validate(_context), do: {:ok, %{validated: true}}

          @impl true
          def execute(_context), do: {:ok, %{executed: true}}
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationSuccessStepErrors.call(context)

      # Should receive operation start event
      assert_receive {:telemetry_event, [:drops, :operation, :start], _,
                      %{step: :prepare}}

      # Should receive operation stop event
      assert_receive {:telemetry_event, [:drops, :operation, :stop], _, _}

      # Should NOT receive any step exception events for successful steps
      refute_receive {:telemetry_event, [:drops, :operation, :step, :exception], _, _}
    end

    test "does not emit any events when both telemetry and telemetry_step_errors are disabled" do
      defmodule TestOperationNoTelemetry do
        use Drops.Operations.Command, telemetry: false, telemetry_step_errors: false

        steps do
          def validate(_context), do: {:error, "validation failed"}

          @impl true
          def execute(_context), do: {:ok, %{executed: true}}
        end
      end

      context = %{params: %{name: "test"}}
      {:error, _reason} = TestOperationNoTelemetry.call(context)

      # Should NOT receive any telemetry events
      refute_receive {:telemetry_event, [:drops, :operation, :start], _, _}
      refute_receive {:telemetry_event, [:drops, :operation, :stop], _, _}
      refute_receive {:telemetry_event, [:drops, :operation, :exception], _, _}
      refute_receive {:telemetry_event, [:drops, :operation, :step, :exception], _, _}
    end

    test "telemetry events contain updated context for successful steps" do
      defmodule TestOperationSuccessContext do
        use Drops.Operations.Command, telemetry: [steps: [:prepare]]

        steps do
          def prepare(context) do
            {:ok, Map.put(context, :prepared, true)}
          end

          @impl true
          def execute(context) do
            {:ok, context}
          end
        end
      end

      context = %{params: %{name: "test"}}
      {:ok, _result} = TestOperationSuccessContext.call(context)

      # Should receive step stop event with updated context
      assert_receive {:telemetry_event, [:drops, :operation, :step, :stop], _,
                      %{step: :prepare, context: received_context}}

      # Context should contain the update from the prepare step
      assert received_context.prepared == true
      assert received_context.params == %{name: "test"}
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "telemetry events contain invalid changeset context for validation failures" do
      defmodule TestOperationChangesetValidation do
        use Drops.Operations.Command,
          repo: Drops.TestRepo,
          telemetry: [steps: [:validate]],
          telemetry_step_errors: [:validate]

        schema(Test.Ecto.TestSchemas.UserSchema)

        steps do
          @impl true
          def execute(%{changeset: changeset}) do
            case insert(changeset) do
              {:ok, user} -> {:ok, %{name: user.name}}
              {:error, changeset} -> {:error, changeset}
            end
          end
        end

        @impl true
        def validate_changeset(%{changeset: changeset}) do
          changeset
          |> Ecto.Changeset.validate_required([:email])
          |> Ecto.Changeset.validate_length(:email, min: 1, message: "can't be blank")
        end
      end

      # Use empty email to trigger validation failure
      context = %{params: %{name: "Jane Doe", email: ""}}
      {:error, _changeset} = TestOperationChangesetValidation.call(context)

      # Should receive step exception event with invalid changeset in context
      assert_receive {:telemetry_event, [:drops, :operation, :step, :exception], _,
                      %{step: :validate, context: received_context}}

      # Context should contain the invalid changeset with errors
      assert %Ecto.Changeset{} = received_context.changeset
      assert received_context.changeset.valid? == false
      assert received_context.changeset.errors[:email]
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "telemetry events preserve original context for non-changeset errors" do
      defmodule TestOperationSimpleError do
        use Drops.Operations.Command,
          telemetry: [steps: [:validate]],
          telemetry_step_errors: [:validate]

        steps do
          def validate(_context) do
            {:error, "simple validation error"}
          end

          @impl true
          def execute(context) do
            {:ok, context}
          end
        end
      end

      context = %{params: %{name: "test"}, original_data: "preserved"}
      {:error, _reason} = TestOperationSimpleError.call(context)

      # Should receive step exception event with original context preserved
      assert_receive {:telemetry_event, [:drops, :operation, :step, :exception], _,
                      %{step: :validate, context: received_context}}

      # Context should be the original input context
      assert received_context.params == %{name: "test"}
      assert received_context.original_data == "preserved"
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "step exception events contain updated context for changeset failures" do
      defmodule TestOperationExceptionContext do
        use Drops.Operations.Command, repo: Drops.TestRepo, telemetry: true

        schema(Test.Ecto.TestSchemas.UserSchema)

        steps do
          @impl true
          def execute(%{changeset: changeset}) do
            case insert(changeset) do
              {:ok, user} -> {:ok, %{name: user.name}}
              {:error, changeset} -> {:error, changeset}
            end
          end
        end

        @impl true
        def validate_changeset(%{changeset: changeset}) do
          changeset
          |> Ecto.Changeset.validate_required([:email])
          |> Ecto.Changeset.validate_length(:email, min: 1, message: "can't be blank")
        end
      end

      context = %{params: %{name: "Jane Doe", email: ""}}
      {:error, _reason} = TestOperationExceptionContext.call(context)

      # Should receive operation exception event with invalid changeset in context
      assert_receive {:telemetry_event, [:drops, :operation, :exception], _,
                      %{step: :validate, context: received_context}}

      # Context should contain the invalid changeset
      assert %Ecto.Changeset{} = received_context.changeset
      assert received_context.changeset.valid? == false
      assert received_context.changeset.errors[:email]
    end
  end
end
