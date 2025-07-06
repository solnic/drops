defmodule Drops.LoggerTest do
  use ExUnit.Case, async: false
  use Drops.LoggerCase

  require Logger, as: ElixirLogger

  alias Drops.Logger, as: DropsLogger

  describe "init/0" do
    @describetag logger: false

    test "initializes handler when logger configuration is present" do
      Application.put_env(:drops, :logger,
        handler: :memory,
        level: :debug
      )

      assert :ok = DropsLogger.init()

      # Verify handler was added
      {:ok, _config} = :logger.get_handler_config(:drops_handler)
    end

    test "does not initialize handler when no logger configuration" do
      Application.put_env(:drops, :logger, [])

      assert :ok = DropsLogger.init()

      # Verify handler was not added
      assert {:error, {:not_found, :drops_handler}} =
               :logger.get_handler_config(:drops_handler)
    end
  end

  describe "add_handler/0" do
    @describetag logger: false

    test "adds debug handler with console configuration" do
      Application.put_env(:drops, :logger,
        handler: :console,
        level: :debug
      )

      assert :ok = DropsLogger.add_handler()

      # Verify handler was added
      {:ok, _config} = :logger.get_handler_config(:drops_handler)
    end

    @tag logger: [handler: :file, file: "test/tmp/test.log", level: :debug]
    test "adds debug handler with file configuration" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler was added
      {:ok, _config} = :logger.get_handler_config(:drops_handler)
    end

    test "adds debug handler with memory configuration" do
      Application.put_env(:drops, :logger,
        handler: :memory,
        level: :debug
      )

      assert :ok = DropsLogger.add_handler()

      # Verify handler was added
      {:ok, _config} = :logger.get_handler_config(:drops_handler)
    end

    test "returns ok when handler already exists" do
      Application.put_env(:drops, :logger,
        handler: :memory,
        level: :debug
      )

      assert :ok = DropsLogger.add_handler()
      # Second call should also return :ok
      assert :ok = DropsLogger.add_handler()
    end

    test "uses default configuration when no config provided" do
      Application.put_env(:drops, :logger, [])

      assert :ok = DropsLogger.add_handler()

      # Verify handler was added with defaults
      {:ok, _config} = :logger.get_handler_config(:drops_handler)
    end
  end

  describe "remove_handler/0" do
    @describetag logger: false

    test "removes debug handler successfully" do
      Application.put_env(:drops, :logger,
        handler: :memory,
        level: :debug
      )

      DropsLogger.add_handler()

      # Verify handler exists
      {:ok, _config} = :logger.get_handler_config(:drops_handler)

      assert :ok = DropsLogger.remove_handler()

      # Verify handler was removed
      assert {:error, {:not_found, :drops_handler}} =
               :logger.get_handler_config(:drops_handler)
    end

    test "returns ok when handler does not exist" do
      assert :ok = DropsLogger.remove_handler()
    end
  end

  describe "memory handler operations" do
    @describetag logger: [
                   handler: :memory,
                   level: :debug,
                   formatter:
                     {Drops.Logger.Formatter.String, [add_newline: true, colorize: false]},
                   metadata: [:operation, :step]
                 ]

    test "get_logs/0 returns captured logs" do
      # Initially empty
      assert DropsLogger.get_logs() == []

      # Log a debug message with metadata
      ElixirLogger.debug("Test message", operation: "TestOp", step: "test_step")

      # Give logger time to process
      Process.sleep(50)

      logs = DropsLogger.get_logs()
      assert length(logs) == 1
      assert hd(logs) =~ "Test message"
    end

    test "clear_logs/0 clears captured logs" do
      # Log a message
      ElixirLogger.debug("Test message", operation: "TestOp", step: "test_step")

      # Give logger time to process
      Process.sleep(10)

      # Verify log exists
      assert length(DropsLogger.get_logs()) == 1

      # Clear logs
      assert :ok = DropsLogger.clear_logs()

      # Verify logs are cleared
      assert DropsLogger.get_logs() == []
    end

    test "logs are captured for all levels with operation metadata" do
      # Log at different levels
      ElixirLogger.debug("Debug message", operation: "TestOp", step: "test_step")
      ElixirLogger.info("Info message", operation: "TestOp", step: "test_step")
      ElixirLogger.warning("Warning message", operation: "TestOp", step: "test_step")

      # Give logger time to process
      Process.sleep(10)

      logs = DropsLogger.get_logs()
      # All operation-related messages should be captured
      assert length(logs) == 3
      assert Enum.any?(logs, &(&1 =~ "Debug message"))
      assert Enum.any?(logs, &(&1 =~ "Info message"))
      assert Enum.any?(logs, &(&1 =~ "Warning message"))
    end

    test "non-operation logs are not captured" do
      # Log at different levels
      ElixirLogger.debug("Debug message")
      ElixirLogger.info("Info message")
      ElixirLogger.warning("Warning message")

      # Give logger time to process
      Process.sleep(10)

      logs = DropsLogger.get_logs()

      assert logs == []
    end
  end

  describe "formatter configuration" do
    @tag logger: [handler: :console, level: :debug]
    test "configures string formatter for console handler" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler was configured with string formatter
      {:ok, config} = :logger.get_handler_config(:drops_handler)

      assert {Drops.Logger.Formatter.String, %Drops.Logger.Formatter.Config{}} =
               config.formatter

      assert config.level == :debug
    end

    @tag logger: [
           handler: :console,
           formatter:
             {Drops.Logger.Formatter.Structured, [add_newline: true, colorize: false]},
           level: :debug
         ]
    test "configures JSON formatter for console handler" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler was configured with JSON formatter
      {:ok, config} = :logger.get_handler_config(:drops_handler)

      assert {Drops.Logger.Formatter.Structured, %Drops.Logger.Formatter.Config{}} =
               config.formatter

      assert config.level == :debug
    end

    @tag logger: [handler: :file, file: "test/tmp/formatter_test.log", level: :debug]
    test "configures string formatter for file handler" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler was configured with string formatter
      {:ok, config} = :logger.get_handler_config(:drops_handler)

      assert {Drops.Logger.Formatter.String, %Drops.Logger.Formatter.Config{}} =
               config.formatter

      assert config.level == :debug
    end

    @tag logger: [
           handler: :file,
           file: "test/tmp/formatter_test.log",
           formatter:
             {Drops.Logger.Formatter.Structured, [add_newline: true, colorize: false]},
           level: :debug
         ]
    test "configures JSON formatter for file handler" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler was configured with JSON formatter
      {:ok, config} = :logger.get_handler_config(:drops_handler)

      assert {Drops.Logger.Formatter.Structured, %Drops.Logger.Formatter.Config{}} =
               config.formatter

      assert config.level == :debug
    end

    @tag logger: [handler: :console, level: :debug]
    test "defaults to string formatter when not specified" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler defaults to string formatter
      {:ok, config} = :logger.get_handler_config(:drops_handler)
      # The formatter config should be normalized to String formatter
      assert {Drops.Logger.Formatter.String, %Drops.Logger.Formatter.Config{}} =
               config.formatter
    end
  end

  describe "built-in handler integration" do
    @tag logger: [handler: :console, level: :debug]
    test "uses logger_std_h for console handler" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler uses built-in logger_std_h module
      {:ok, config} = :logger.get_handler_config(:drops_handler)
      assert config.module == :logger_std_h
      assert config.config.type == :standard_io
    end

    @tag logger: [handler: :file, file: "test/tmp/builtin_test.log", level: :debug]
    test "uses logger_std_h for file handler" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler uses built-in logger_std_h module
      {:ok, config} = :logger.get_handler_config(:drops_handler)
      assert config.module == :logger_std_h
      assert String.ends_with?(to_string(config.config.file), "test/tmp/builtin_test.log")
    end

    @tag logger: [handler: :memory, level: :debug]
    test "uses custom TestHandler for memory handler" do
      assert :ok = DropsLogger.add_handler()

      # Verify handler uses custom DebugHandler module
      {:ok, config} = :logger.get_handler_config(:drops_handler)
      assert config.module == Drops.Logger.TestHandler
    end
  end
end
