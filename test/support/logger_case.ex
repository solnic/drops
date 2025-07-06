defmodule Drops.LoggerCase do
  @moduledoc """
  Test case template for tests that need logger configuration.

  This module provides a clean way to configure Drops logger for tests using
  ExUnit tags. It handles setup and cleanup of logger configuration automatically.

  ## Usage

  Use this case template in your test modules:

      defmodule MyTest do
        use Drops.LoggerCase

        @tag logger: [handler: :memory, level: :debug]
        test "logs debug messages" do
          # Your test code here
          # Logger is automatically configured based on the tag
        end
      end

  ## Logger Tag Options

  The `@tag logger: opts` supports all standard Drops logger configuration options:

  * `:handler` - Handler type (`:console`, `:file`, `:memory`) - defaults to `:memory`
  * `:level` - Log level (`:debug`, `:info`, `:warning`, `:error`) - defaults to `:debug`
  * `:formatter` - Formatter configuration - defaults to string formatter without colors
  * `:metadata` - Metadata fields to include - defaults to operation-related fields
  * `:file` - File path when using `:file` handler

  ## Examples

      # Basic memory handler for testing
      @tag logger: true
      test "basic logging" do
        # Uses default memory handler with debug level
      end

      # Custom configuration
      @tag logger: [handler: :memory, level: :info, formatter: {Drops.Logger.Formatter.Structured, []}]
      test "structured logging" do
        # Uses memory handler with info level and structured formatter
      end

      # File logging
      @tag logger: [handler: :file, file: "test/tmp/test.log"]
      test "file logging" do
        # Logs to specified file
      end

  ## Automatic Cleanup

  The logger configuration is automatically restored to its original state
  after each test, ensuring test isolation.
  """

  use ExUnit.CaseTemplate

  using do
    quote do
      alias Drops.Logger, as: DropsLogger
      require Logger, as: ElixirLogger
    end
  end

  setup tags do
    # Check if logger tag is present
    case Map.get(tags, :logger) do
      nil ->
        # No logger configuration needed, but ensure clean state
        setup_clean_logger_state()

      true ->
        # Use default logger configuration
        setup_logger([])

      false ->
        # Explicitly disable logger, but ensure clean state
        setup_clean_logger_state()

      opts when is_list(opts) ->
        # Use custom logger configuration
        setup_logger(opts)

      opts ->
        raise ArgumentError, """
        Invalid logger tag value: #{inspect(opts)}

        Expected one of:
        - true (use defaults)
        - false (disable)
        - keyword list with options

        Example: @tag logger: [handler: :memory, level: :debug]
        """
    end
  end

  @default_logger_config [
    handler: :memory,
    level: :debug,
    formatter: {Drops.Logger.Formatter.String, [add_newline: true, colorize: false]},
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

  defp setup_clean_logger_state do
    # Store all original configurations for cleanup
    original_drops_config = Application.get_env(:drops, :logger, [])

    # Ensure handler is removed before each test
    Drops.Logger.remove_handler()

    # Setup cleanup to restore original state
    ExUnit.Callbacks.on_exit(fn ->
      Drops.Logger.remove_handler()
      Application.put_env(:drops, :logger, original_drops_config)
      Drops.Logger.clear_logs()
    end)

    :ok
  end

  defp setup_logger(opts) do
    # Store all original configurations
    original_drops_config = Application.get_env(:drops, :logger, [])
    original_logger_level = Application.get_env(:logger, :level)
    original_primary_config = :logger.get_primary_config()
    original_process_level = Logger.level()

    # Get original default handler config
    original_default_level =
      case :logger.get_handler_config(:default) do
        {:ok, config} -> config.level
        _ -> :all
      end

    # Merge provided options with defaults, but allow complete override
    logger_config =
      if Keyword.keyword?(opts) and length(opts) > 0 do
        # If specific options provided, merge with defaults
        Keyword.merge(@default_logger_config, opts)
      else
        # Use defaults
        @default_logger_config
      end

    # Apply logger configuration
    Application.put_env(:drops, :logger, logger_config)

    # Set logger configuration to allow debug logs
    Application.put_env(:logger, :level, :debug)
    :logger.set_primary_config(level: :debug)

    # Also set process-level logger to debug to override any process-level filtering
    Logger.configure(level: :debug)

    # Suppress debug output from default console handler during tests
    :logger.set_handler_config(:default, :level, :warning)

    # Remove any existing handler and add the new one
    Drops.Logger.remove_handler()
    Drops.Logger.add_handler()

    # Clear any existing logs
    Drops.Logger.clear_logs()

    # Setup cleanup
    ExUnit.Callbacks.on_exit(fn ->
      # Clean up in reverse order
      Drops.Logger.remove_handler()
      Drops.Logger.clear_logs()

      # Clean up file if file handler was used
      case Keyword.get(logger_config, :handler) do
        :file ->
          if file_path = Keyword.get(logger_config, :file) do
            # Clean up the specific file and its directory if empty
            File.rm_rf!(Path.dirname(file_path))
          end

        _ ->
          :ok
      end

      # Restore all original configurations
      :logger.set_handler_config(:default, :level, original_default_level)
      Application.put_env(:drops, :logger, original_drops_config)

      if original_logger_level do
        Application.put_env(:logger, :level, original_logger_level)
      else
        Application.delete_env(:logger, :level)
      end

      :logger.set_primary_config(original_primary_config)
      Logger.configure(level: original_process_level)
    end)

    :ok
  end
end
