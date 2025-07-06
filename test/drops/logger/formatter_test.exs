defmodule Drops.Logger.FormatterTest do
  use ExUnit.Case, async: true
  use Drops.LoggerCase

  alias Drops.Logger.Formatter.String, as: StringFormatter
  alias Drops.Logger.Formatter.Structured, as: StructuredFormatter
  alias Drops.Logger.Formatter.Config

  # Test struct for JSON encoding error tests
  defmodule TestStruct do
    @derive Jason.Encoder
    defstruct [:value]
  end

  describe "String formatter" do
    test "formats operation logs with string formatter" do
      log_event = %{
        level: :debug,
        msg: {:string, "Starting step execute"},
        meta: %{operation: "TestOp", step: :execute},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)

      assert result =~ "[debug] Starting step execute"
      assert result =~ "operation=\"TestOp\""
      assert result =~ "step=:execute"
    end

    test "formats operation logs with binary message" do
      log_event = %{
        level: :info,
        msg: "Test message",
        meta: %{operation: "TestOp"},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)

      assert result =~ "[info] Test message"
      assert result =~ "operation=\"TestOp\""
    end

    test "formats operation logs with format tuple message" do
      log_event = %{
        level: :warning,
        msg: {"Step ~s failed with ~p", ["execute", :timeout]},
        meta: %{operation: "TestOp", step: :execute},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)

      assert result =~ "[warning] Step execute failed with timeout"
      assert result =~ "operation=\"TestOp\""
      assert result =~ "step=:execute"
    end

    test "handles logs with only operation metadata" do
      log_event = %{
        level: :debug,
        msg: {:string, "Operation started"},
        meta: %{operation: "TestOp"},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)

      assert result =~ "[debug] Operation started"
      assert result =~ "operation=\"TestOp\""
      refute result =~ "step="
    end
  end

  describe "Structured formatter" do
    test "formats operation logs as JSON" do
      timestamp = System.os_time(:microsecond)

      log_event = %{
        level: :debug,
        msg: {:string, "Starting step execute"},
        meta: %{operation: "TestOp", step: :execute},
        time: timestamp
      }

      config = %Config{colorize: false, add_newline: true}
      result = StructuredFormatter.format(log_event, config)

      # Parse JSON to verify structure
      assert {:ok, json} = Jason.decode(result)
      assert json["level"] == "debug"
      assert json["message"] == "Starting step execute"
      assert json["metadata"]["operation"] == "TestOp"
      assert json["metadata"]["step"] == "execute"
      assert json["timestamp"] == div(timestamp, 1000)
    end
  end

  describe "message extraction" do
    test "extracts binary messages" do
      log_event = %{
        level: :debug,
        msg: "Test message",
        meta: %{operation: "TestOp"},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)
      assert result =~ "Test message"
    end

    test "extracts list messages" do
      log_event = %{
        level: :debug,
        msg: [~c"Test", ~c" message"],
        meta: %{operation: "TestOp"},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)
      assert result =~ "Test message"
    end

    test "extracts format tuple messages" do
      log_event = %{
        level: :debug,
        msg: {"Hello ~s", ["world"]},
        meta: %{operation: "TestOp"},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)
      assert result =~ "Hello world"
    end

    test "extracts string tuple messages" do
      log_event = %{
        level: :debug,
        msg: {:string, "String tuple message"},
        meta: %{operation: "TestOp"},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)
      assert result =~ "String tuple message"
    end

    test "handles unknown message formats" do
      log_event = %{
        level: :debug,
        msg: %{unknown: "format"},
        meta: %{operation: "TestOp"},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)
      assert result =~ "%{unknown: \"format\"}"
    end
  end

  describe "operation log filtering" do
    test "identifies operation logs with operation metadata" do
      log_event = %{
        level: :debug,
        msg: {:string, "Test"},
        meta: %{operation: "TestOp"},
        time: System.os_time(:microsecond)
      }

      config = %Config{colorize: false, add_newline: true}
      refute StringFormatter.format(log_event, config) == ""
      refute StructuredFormatter.format(log_event, config) == ""
    end
  end

  describe "error metadata coloring" do
    @tag logger: [metadata: [:operation, :error_code, :error_message]]
    test "applies red color to metadata values when key starts with 'error' and colorization is enabled" do
      log_event = %{
        level: :debug,
        msg: {:string, "Operation failed"},
        meta: %{
          operation: "TestOp",
          error_code: 500,
          error_message: "Internal server error"
        },
        time: System.os_time(:microsecond)
      }

      # Enable colorization in config
      config = %Config{colorize: true, add_newline: true}
      result = StringFormatter.format(log_event, config)

      # Check if ANSI is enabled in test environment
      if IO.ANSI.enabled?() do
        # Check that error_code and error_message values are colored red
        red = IO.ANSI.red()
        reset = IO.ANSI.reset()

        assert result =~ "error_code=#{red}500#{reset}"
        assert result =~ "error_message=#{red}\"Internal server error\"#{reset}"
        # Regular metadata should not be colored red
        assert result =~ "operation=\"TestOp\""
        refute result =~ "operation=#{red}"
      else
        # If ANSI is disabled, should fall back to plain format
        refute result =~ "\e["
        assert result =~ "error_code=500"
        assert result =~ "error_message=\"Internal server error\""
        assert result =~ "operation=\"TestOp\""
      end
    end

    @tag logger: [metadata: [:operation, :error_code]]
    test "does not apply red color when colorization is disabled" do
      log_event = %{
        level: :debug,
        msg: {:string, "Operation failed"},
        meta: %{
          operation: "TestOp",
          error_code: 500
        },
        time: System.os_time(:microsecond)
      }

      # Disable colorization in config
      config = %Config{colorize: false, add_newline: true}
      result = StringFormatter.format(log_event, config)

      # Check that no ANSI color codes are present
      refute result =~ IO.ANSI.red()
      refute result =~ IO.ANSI.reset()
      assert result =~ "error_code=500"
      assert result =~ "operation=\"TestOp\""
    end

    @tag logger: [metadata: [:operation, :step, :status]]
    test "does not apply red color to non-error metadata keys" do
      log_event = %{
        level: :debug,
        msg: {:string, "Operation completed"},
        meta: %{
          operation: "TestOp",
          step: :execute,
          status: "success"
        },
        time: System.os_time(:microsecond)
      }

      # Enable colorization in config
      config = %Config{colorize: true, add_newline: true}
      result = StringFormatter.format(log_event, config)

      # Check that no metadata values are colored red since no keys start with "error"
      red = IO.ANSI.red()
      refute result =~ "operation=#{red}"
      refute result =~ "step=#{red}"
      refute result =~ "status=#{red}"
    end

    @tag logger: [metadata: [:operation, :step, :error_type, :errors]]
    test "applies faint color to non-error metadata and red color to error metadata" do
      log_event = %{
        level: :debug,
        msg: {:string, "SaveUser.validate failed"},
        meta: %{
          operation: "SaveUser",
          step: :validate,
          error_type: "Ecto.Changeset",
          errors: "name: can't be blank"
        },
        time: System.os_time(:microsecond)
      }

      # Enable colorization in config
      config = %Config{colorize: true, add_newline: true}
      result = StringFormatter.format(log_event, config)

      # Check if ANSI is enabled in test environment
      if IO.ANSI.enabled?() do
        # Check that error metadata values are colored red
        red = IO.ANSI.red()
        reset = IO.ANSI.reset()
        assert result =~ "error_type=#{red}\"Ecto.Changeset\"#{reset}"
        assert result =~ "errors=#{red}\"name: can't be blank\"#{reset}"

        # Check that non-error metadata is colored faint
        faint = IO.ANSI.faint()
        assert result =~ "#{faint}operation=\"SaveUser\"#{reset}"
        assert result =~ "#{faint}step=:validate#{reset}"
      else
        # If ANSI is disabled, should fall back to plain format
        refute result =~ "\e["
        assert result =~ "error_type=\"Ecto.Changeset\""
        assert result =~ "errors=\"name: can't be blank\""
        assert result =~ "operation=\"SaveUser\""
        assert result =~ "step=:validate"
      end
    end
  end
end
