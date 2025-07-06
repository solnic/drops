defmodule Drops.Operations.Extensions.LoggingTest do
  use Drops.OperationCase, async: false

  # Configure logger for all tests in this module
  @moduletag logger: [
               handler: :memory,
               level: :debug,
               formatter:
                 {Drops.Logger.Formatter.String, [add_newline: true, colorize: false]},
               metadata: [
                 :operation,
                 :step,
                 :context,
                 :reason,
                 :error_type,
                 :errors,
                 :kind,
                 :duration_us
               ]
             ]

  alias Drops.Logger

  defmodule TestHandler do
    def handle_event(event, measurements, metadata, _config) do
      send(self(), {:telemetry_event, event, measurements, metadata})
    end
  end

  setup do
    # Setup telemetry cleanup (LoggerCase handles logger setup/cleanup)
    on_exit(fn ->
      # Detach any telemetry handlers that might have been attached during tests
      # This prevents interference between tests
      detach_all_logging_handlers()
    end)

    :ok
  end

  # Helper function to detach all logging telemetry handlers
  defp detach_all_logging_handlers do
    # Get all attached telemetry handlers
    handlers = :telemetry.list_handlers([])

    # Find and detach all handlers that start with "logging-"
    Enum.each(handlers, fn handler ->
      if String.starts_with?(handler.id, "logging-") do
        try do
          :telemetry.detach(handler.id)
        rescue
          _ -> :ok
        end
      end
    end)
  end

  describe "when debug is enabled" do
    operation type: :command, debug: true do
      schema do
        %{
          required(:name) => string(),
          required(:age) => integer()
        }
      end

      steps do
        @impl true
        def execute(context) do
          {:ok, context}
        end
      end
    end

    test "logging operation start/stop events by default", %{operation: operation} do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name = operation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log operation start/stop events (first and last steps)
      assert log_output =~ "#{operation_name}.conform started"
      assert log_output =~ "#{operation_name}.conform succeeded in"
      assert log_output =~ "#{operation_name}.execute started"
      assert log_output =~ "#{operation_name}.execute succeeded in"
    end

    test "logging operation's step start/stop events by default", %{operation: operation} do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name = operation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log all step start/stop events
      assert log_output =~ "#{operation_name}.conform started"
      assert log_output =~ "#{operation_name}.conform succeeded in"
      assert log_output =~ "#{operation_name}.execute started"
      assert log_output =~ "#{operation_name}.execute succeeded in"
    end

    test "logs duration with proper precision formatting", %{operation: operation} do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Should contain duration information with proper units
      # Fast operations should show microseconds (μs)
      # Slower operations might show milliseconds (ms) or seconds (s)
      duration_patterns = [
        # microseconds
        ~r/succeeded in \d+μs/,
        # milliseconds
        ~r/succeeded in \d+\.\d+ms/,
        # seconds
        ~r/succeeded in \d+\.\d+s/
      ]

      # At least one duration pattern should match
      assert Enum.any?(duration_patterns, fn pattern ->
               Regex.match?(pattern, log_output)
             end),
             "Expected to find duration with proper unit formatting in: #{log_output}"
    end

    test "duration formatting converts microseconds correctly" do
      # Since format_duration is private, we'll test it through telemetry events
      # Create mock telemetry events with known durations and verify the log output

      # Clear logs before test
      Logger.clear_logs()

      # Test different duration ranges by simulating telemetry events
      test_cases = [
        # microseconds
        {500, "500μs"},
        # milliseconds
        {1_500, "1.5ms"},
        # seconds (from your example)
        {14_096_948, "14.1s"},
        # seconds (from your example)
        {32_596_681, "32.6s"}
      ]

      for {duration_us, _expected_display} <- test_cases do
        # Convert from microseconds to native time units for the telemetry measurement
        duration_native = System.convert_time_unit(duration_us, :microsecond, :native)

        # Simulate a telemetry event
        measurements = %{duration: duration_native}
        metadata = %{operation: TestOperation, step: :execute, context: %{}}
        config = %{logging_config: %{level: :info, include_context: false}}

        Drops.Operations.Extensions.Logging.handle_logging_event(
          [:test, :operation, :stop],
          measurements,
          metadata,
          config
        )
      end

      # Get captured logs and verify duration formatting
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Verify each expected duration appears in the logs
      for {_duration_us, expected_display} <- test_cases do
        assert String.contains?(log_output, "succeeded in #{expected_display}"),
               "Expected to find '#{expected_display}' in logs: #{log_output}"
      end
    end

    test "logs contain proper metadata for operation filtering", %{operation: operation} do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()

      # All logs should contain operation metadata (required for formatter filtering)
      assert length(logs) > 0, "Expected debug logs to be captured"

      Enum.each(logs, fn log ->
        # Each log should contain operation metadata (without Elixir. prefix)
        operation_name = operation |> to_string() |> String.replace_prefix("Elixir.", "")

        # The operation name is quoted in the metadata
        assert log =~ "operation=\"#{operation_name}\"",
               "Expected log to contain operation metadata: #{log}"

        # Step-level logs (containing a dot) should contain step metadata
        # Operation-level logs (without a dot) should not contain step metadata
        if log =~ "started" or log =~ "succeeded" do
          if String.contains?(log, ".") do
            # This is a step-level log (e.g., "OperationName.step_name started")
            assert log =~ "step=",
                   "Expected step-level log to contain step metadata: #{log}"
          else
            # This is an operation-level log (e.g., "OperationName started")
            refute log =~ "step=",
                   "Expected operation-level log to NOT contain step metadata: #{log}"
          end
        end
      end)
    end
  end

  describe "when debug is disabled" do
    operation type: :command, debug: false do
      schema do
        %{
          required(:name) => string(),
          required(:age) => integer()
        }
      end

      steps do
        @impl true
        def execute(context) do
          {:ok, context}
        end
      end
    end

    test "does not log debug messages", %{operation: operation} do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()

      # Should not contain debug logs from the Logging extension
      assert logs == []
    end
  end

  describe "when logging is enabled" do
    operation type: :command, logging: true do
      schema do
        %{
          required(:name) => string(),
          required(:age) => integer()
        }
      end

      steps do
        @impl true
        def execute(context) do
          {:ok, context}
        end
      end
    end

    test "logs at info level without context for successful operations", %{
      operation: operation
    } do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name = operation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log operation-level events at info level (operation boundaries)
      assert log_output =~ "#{operation_name} started"
      assert log_output =~ "#{operation_name} succeeded in"

      # Should not contain context in successful operations
      refute log_output =~ "context="
    end
  end

  describe "when logging is enabled with specific steps" do
    operation type: :command, logging: [steps: [:execute]] do
      schema do
        %{
          required(:name) => string(),
          required(:age) => integer()
        }
      end

      steps do
        @impl true
        def execute(context) do
          {:ok, context}
        end
      end
    end

    test "logs only specified steps", %{operation: operation} do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name = operation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log execute step
      assert log_output =~ "#{operation_name}.execute started"
      assert log_output =~ "#{operation_name}.execute succeeded in"

      # Should not log conform step (not in specified steps)
      refute log_output =~ "#{operation_name}.conform started"
    end
  end

  describe "when logging is enabled with all steps" do
    operation type: :command, logging: [steps: :all] do
      schema do
        %{
          required(:name) => string(),
          required(:age) => integer()
        }
      end

      steps do
        @impl true
        def execute(context) do
          {:ok, context}
        end
      end
    end

    test "logs all steps at info level without context", %{operation: operation} do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name = operation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log all step start/stop events
      assert log_output =~ "#{operation_name}.conform started"
      assert log_output =~ "#{operation_name}.conform succeeded in"
      assert log_output =~ "#{operation_name}.execute started"
      assert log_output =~ "#{operation_name}.execute succeeded in"

      # Should not contain context in successful operations
      refute log_output =~ "context="
    end
  end

  describe "when debug is enabled with custom identifier" do
    operation type: :command, debug: [identifier: :my_app] do
      schema do
        %{
          required(:name) => string(),
          required(:age) => integer()
        }
      end

      steps do
        @impl true
        def execute(context) do
          {:ok, context}
        end
      end
    end

    test "logs debug messages with custom identifier", %{operation: operation} do
      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:ok, _result} = operation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name = operation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log all step start/stop events
      assert log_output =~ "#{operation_name}.conform started"
      assert log_output =~ "#{operation_name}.conform succeeded in"
      assert log_output =~ "#{operation_name}.execute started"
      assert log_output =~ "#{operation_name}.execute succeeded in"
    end
  end

  describe "formatter colorization" do
    test "supports colorization option" do
      log_event = %{
        level: :debug,
        msg: {:string, "Test message"},
        meta: %{operation: "TestOp", step: "test"}
      }

      # Test with colorization enabled
      config = %Drops.Logger.Formatter.Config{colorize: true, add_newline: false}
      colored_output = Drops.Logger.Formatter.String.format(log_event, config)

      # Check if ANSI is enabled in test environment
      if IO.ANSI.enabled?() do
        # Cyan color for debug level
        assert String.contains?(colored_output, "\e[36m[debug]\e[0m")
        # Faint color for metadata
        assert String.contains?(colored_output, "\e[2m")
      else
        # If ANSI is disabled, should fall back to plain format
        refute String.contains?(colored_output, "\e[")
      end

      # Test with colorization disabled
      config = %Drops.Logger.Formatter.Config{colorize: false, add_newline: false}
      plain_output = Drops.Logger.Formatter.String.format(log_event, config)
      # No ANSI escape codes
      refute String.contains?(plain_output, "\e[")
      assert String.contains?(plain_output, "[debug]")
    end

    test "uses different colors for different log levels" do
      # Skip this test if ANSI is not enabled
      if IO.ANSI.enabled?() do
        test_cases = [
          # cyan
          {:debug, "\e[36m"},
          # normal
          {:info, "\e[0m"},
          # yellow
          {:warning, "\e[33m"},
          # red
          {:error, "\e[31m"}
        ]

        for {level, expected_color} <- test_cases do
          log_event = %{
            level: level,
            msg: {:string, "Test message"},
            meta: %{operation: "TestOp", step: "test"}
          }

          config = %Drops.Logger.Formatter.Config{colorize: true, add_newline: false}
          output = Drops.Logger.Formatter.String.format(log_event, config)

          assert String.contains?(output, expected_color),
                 "Expected #{level} to contain color code #{expected_color}"
        end
      end
    end
  end

  describe "error logging" do
    @tag :error_logging
    test "logs error events at error level with context for failed operations" do
      defmodule TestErrorOperation do
        use Drops.Operations.Command, logging: true

        schema do
          %{
            required(:name) => string(),
            required(:age) => integer()
          }
        end

        steps do
          @impl true
          def execute(_context) do
            {:error, "something went wrong"}
          end
        end
      end

      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:error, _reason} = TestErrorOperation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name =
        TestErrorOperation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log operation start event (operation-level telemetry)
      assert log_output =~ "#{operation_name} started"

      # Should log step failure at error level with context (step-level error telemetry)
      assert log_output =~ "#{operation_name}.execute failed in"
      assert log_output =~ "reason="
      assert log_output =~ "kind=:error"
      assert log_output =~ "context="
    end

    @tag :error_logging
    test "does not log error events for non-last steps by default" do
      defmodule TestValidateErrorOperation do
        use Drops.Operations.Command, logging: true

        schema do
          %{
            required(:name) => string(),
            required(:age) => integer()
          }
        end

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

      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:error, _reason} = TestValidateErrorOperation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name =
        TestValidateErrorOperation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log operation start event (operation-level telemetry)
      assert log_output =~ "#{operation_name} started"

      # Should NOT log step failure for non-last steps (validate is not the last step)
      refute log_output =~ "#{operation_name}.validate failed in"
    end

    @tag :error_logging
    test "logs error events for non-last steps when log_all_errors is true" do
      defmodule TestValidateErrorOperationWithAllErrors do
        use Drops.Operations.Command, logging: [log_all_errors: true]

        schema do
          %{
            required(:name) => string(),
            required(:age) => integer()
          }
        end

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

      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:error, _reason} = TestValidateErrorOperationWithAllErrors.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name =
        TestValidateErrorOperationWithAllErrors
        |> to_string()
        |> String.replace_prefix("Elixir.", "")

      # Should log operation start event (operation-level telemetry)
      assert log_output =~ "#{operation_name} started"

      # Should log step failure at error level with context and reason (step-level error telemetry)
      assert log_output =~ "#{operation_name}.validate failed in"
      assert log_output =~ "reason="
      assert log_output =~ "kind=:error"
      assert log_output =~ "context="
    end

    @tag :error_logging
    test "logs error events in debug mode with context" do
      defmodule TestDebugErrorOperation do
        use Drops.Operations.Command, debug: true

        schema do
          %{
            required(:name) => string(),
            required(:age) => integer()
          }
        end

        steps do
          @impl true
          def execute(_context) do
            {:error, "debug mode error"}
          end
        end
      end

      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:error, _reason} = TestDebugErrorOperation.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name =
        TestDebugErrorOperation |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log step-level events in debug mode (all steps instrumented)
      assert log_output =~ "#{operation_name}.execute started"
      assert log_output =~ "#{operation_name}.execute failed in"

      # Should log error with context and reason
      assert log_output =~ "reason="
      assert log_output =~ "kind=:error"
      assert log_output =~ "context="
    end

    @tag :error_logging
    test "logs operation failure at warning level in non-debug mode with limited metadata" do
      defmodule TestOperationFailureLogging do
        use Drops.Operations.Command, logging: true

        schema do
          %{
            required(:name) => string(),
            required(:age) => integer()
          }
        end

        steps do
          @impl true
          def execute(_context) do
            {:error, "operation failed"}
          end
        end
      end

      context = %{params: %{name: "test", age: 30}}

      # Clear logs before test
      Logger.clear_logs()

      {:error, _reason} = TestOperationFailureLogging.call(context)

      # Get captured logs
      logs = Logger.get_logs()
      log_output = Enum.join(logs, "")

      # Get operation name without Elixir. prefix
      operation_name =
        TestOperationFailureLogging |> to_string() |> String.replace_prefix("Elixir.", "")

      # Should log operation start event
      assert log_output =~ "#{operation_name} started"

      # Find the operation failure log line (not the step failure line)
      operation_failure_line =
        logs
        |> Enum.find(fn log ->
          log =~ "#{operation_name} failed in" and not (log =~ ".execute failed in")
        end)

      assert operation_failure_line, "Expected to find operation failure log line"

      # Operation failure should include reason, duration_us, and kind but not context in non-debug mode
      assert operation_failure_line =~ "reason="
      assert operation_failure_line =~ "duration_us="
      assert operation_failure_line =~ "kind="
      refute operation_failure_line =~ "context="

      # Should also log step error (since it's the last step) - this one should have full metadata
      step_failure_line =
        logs
        |> Enum.find(fn log ->
          log =~ "#{operation_name}.execute failed in"
        end)

      assert step_failure_line, "Expected to find step failure log line"
      assert step_failure_line =~ "duration_us="
      assert step_failure_line =~ "kind="
    end
  end

  describe "MetadataDumper protocol" do
    alias Drops.Logger.MetadataDumper

    test "dumps basic types correctly" do
      assert MetadataDumper.dump("test") == "\"test\""
      assert MetadataDumper.dump(42) == "42"
      assert MetadataDumper.dump(:atom) == ":atom"
      assert MetadataDumper.dump([1, 2, 3]) == "[1, 2, 3]"
      assert MetadataDumper.dump([1, 2, 3, 4, 5]) == "[5 items]"
      assert MetadataDumper.dump(%{a: 1, b: 2}) == "%{:a => 1, :b => 2}"
      assert MetadataDumper.dump(%{a: 1, b: 2, c: 3, d: 4}) == "%{4 keys}"
    end

    test "dumps nested structures recursively" do
      # Nested list with maps
      nested = [%{name: "Alice"}, %{name: "Bob"}]
      result = MetadataDumper.dump(nested)
      assert result == "[%{:name => \"Alice\"}, %{:name => \"Bob\"}]"

      # Map with nested structures
      nested_map = %{users: ["Alice", "Bob"], count: 2}
      result = MetadataDumper.dump(nested_map)
      assert result == "%{:count => 2, :users => [\"Alice\", \"Bob\"]}"

      # Complex nested structure (should truncate large collections)
      large_list = Enum.to_list(1..10)
      complex = %{data: large_list, meta: %{total: 10}}
      result = MetadataDumper.dump(complex)
      assert result == "%{:data => [10 items], :meta => %{:total => 10}}"
    end

    test "handles deeply nested structures with mixed types" do
      # Test with various nested types including atoms, strings, numbers
      deep_structure = %{
        user: %{
          profile: %{name: "Alice", age: 30},
          settings: [:notifications, :dark_mode]
        }
      }

      result = MetadataDumper.dump(deep_structure)

      expected =
        "%{:user => %{:profile => %{:age => 30, :name => \"Alice\"}, :settings => [:notifications, :dark_mode]}}"

      assert result == expected
    end

    if Code.ensure_loaded?(Ecto.Changeset) do
      test "dumps Ecto.Changeset correctly" do
        # Valid changeset with changes
        changeset = %Ecto.Changeset{
          valid?: true,
          changes: %{name: "John", age: 30},
          errors: []
        }

        result = MetadataDumper.dump(changeset)
        assert result == "Ecto.Changeset(valid), 2 changes"

        # Invalid changeset with errors
        changeset = %Ecto.Changeset{
          valid?: false,
          changes: %{name: "John"},
          errors: [age: {"is required", []}]
        }

        result = MetadataDumper.dump(changeset)
        assert result == "Ecto.Changeset(invalid), 1 changes, 1 errors"

        # Empty changeset
        changeset = %Ecto.Changeset{
          valid?: true,
          changes: %{},
          errors: []
        }

        result = MetadataDumper.dump(changeset)
        assert result == "Ecto.Changeset(valid)"
      end
    end
  end
end
