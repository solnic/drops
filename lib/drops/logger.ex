defmodule Drops.Logger do
  @moduledoc """
  Logger utilities for Drops operations.

  This module provides functionality for setting up and managing debug logging
  for Drops operations using built-in Erlang logger handlers and custom formatters.

  ## Configuration

  The debug handler can be configured via application environment:

      config :drops, :logger,
        handler: :console,
        file: "log/operations.log",
        level: :debug,
        formatter: {Drops.Logger.Formatter.String, [add_newline: true, colorize: true]},
        metadata: [:operation, :step]

  ## Handler Types

  * `:console` - Logs to standard output using built-in logger_std_h (default)
  * `:file` - Logs to a specified file using built-in logger_std_h
  * `:memory` - Captures logs in memory for testing purposes

  ## Formatter Types

  * `Drops.Logger.Formatter.String` - Human-readable string format with message and metadata (default)
  * `Drops.Logger.Formatter.Structured` - JSON format with message and metadata as structured data

  ## Automatic Initialization

  The debug handler is automatically initialized when the Drops application starts.
  This ensures that operation debug logs are captured from the moment the application
  is running.

  ## Manual Management

  You can manually add or remove the handler if needed:

      # Add the handler
      Drops.Logger.add_handler()

      # Remove the handler
      Drops.Logger.remove_handler()

  ## Testing

  When using the `:memory` handler for testing, you can retrieve and clear logs:

      # Get all captured logs
      logs = Drops.Logger.get_logs()

      # Clear captured logs
      Drops.Logger.clear_logs()
  """

  alias Drops.Logger.TestHandler

  @default_config %{
    handler: :console,
    file: "log/drops.log",
    level: :debug,
    formatter: {Drops.Logger.Formatter.String, [add_newline: true, colorize: true]},
    metadata: :all
  }

  @doc """
  Initializes the debug logger during application startup.

  This function is called automatically by the Drops application and sets up
  the debug handler with the configured settings. It ensures that operation
  debug logs are captured exclusively by the Drops debug handler.

  ## Returns

  Returns `:ok` on success or `{:error, reason}` if initialization fails.
  """
  @spec init() :: :ok | {:error, term()}
  def init do
    case should_initialize_handler?() do
      true -> add_handler()
      false -> :ok
    end
  end

  @doc """
  Adds the debug handler to the logger system.

  This function registers the appropriate handler (built-in or custom) with the logger system
  using the configuration from the application environment.

  For console and file handlers, uses built-in `:logger_std_h` with custom formatters.
  For memory handler, uses custom `DebugHandler` for testing purposes.

  When adding the debug handler, this function also adds a filter to the default
  handler to prevent operation logs from being duplicated.

  ## Returns

  Returns `:ok` on success, or `{:error, reason}` if the handler cannot be added.
  If the handler already exists, returns `:ok`.
  """
  @spec add_handler() :: :ok | {:error, term()}
  def add_handler do
    config = get_handler_config()

    result =
      case config.handler do
        :console ->
          add_console_handler(config)

        :file ->
          add_file_handler(config)

        :memory ->
          add_memory_handler(config)

        _ ->
          {:error, {:invalid_handler, config.handler}}
      end

    case result do
      :ok ->
        # Add filter to default handler to prevent duplicate operation logs
        add_operation_filter_to_default_handler()
        :ok

      error ->
        error
    end
  end

  @doc """
  Removes the debug handler from the logger system.

  When removing the debug handler, this function also removes the operation
  filter from the default handler to restore normal logging behavior.

  ## Returns

  Returns `:ok` on success or `{:error, reason}` if removal fails.
  If the handler doesn't exist, returns `:ok`.
  """
  @spec remove_handler() :: :ok | {:error, term()}
  def remove_handler do
    result =
      case :logger.remove_handler(:drops_handler) do
        :ok -> :ok
        {:error, {:not_found, _}} -> :ok
        error -> error
      end

    case result do
      :ok ->
        # Remove filter from default handler to restore normal logging
        remove_operation_filter_from_default_handler()
        :ok

      error ->
        error
    end
  end

  @doc """
  Gets all captured logs when using memory handler.

  This is a convenience function that delegates to the TestHandler.

  ## Returns

  Returns a list of captured log messages when using the memory handler,
  or an empty list if not using memory handler or no logs captured.
  """
  @spec get_logs() :: [String.t()]
  def get_logs do
    TestHandler.get_logs()
  end

  @doc """
  Clears all captured logs when using memory handler.

  This is a convenience function that delegates to the TestHandler.

  ## Returns

  Returns `:ok`.
  """
  @spec clear_logs() :: :ok
  def clear_logs do
    TestHandler.clear_logs()
  end

  # Private functions

  defp should_initialize_handler? do
    # Only initialize if we have logger configuration
    # This allows users to opt-out by not configuring :logger
    logger_config = Application.get_env(:drops, :logger, [])
    logger_config != []
  end

  defp get_handler_config do
    logger_config = Application.get_env(:drops, :logger, [])

    Enum.reduce(logger_config, @default_config, fn {key, value}, acc ->
      Map.put(acc, key, value)
    end)
  end

  defp add_console_handler(config) do
    {formatter_module, formatter_config} = normalize_formatter_config(config.formatter)

    handler_config = %{
      level: config.level,
      formatter: {formatter_module, formatter_config}
    }

    case :logger.add_handler(:drops_handler, :logger_std_h, handler_config) do
      :ok -> :ok
      {:error, {:already_exist, _}} -> :ok
      error -> error
    end
  end

  defp add_file_handler(config) do
    # Ensure log directory exists
    log_dir = Path.dirname(config.file)
    File.mkdir_p!(log_dir)

    {formatter_module, formatter_config} = normalize_formatter_config(config.formatter)

    handler_config = %{
      config: %{file: String.to_charlist(config.file)},
      level: config.level,
      formatter: {formatter_module, formatter_config}
    }

    case :logger.add_handler(:drops_handler, :logger_std_h, handler_config) do
      :ok -> :ok
      {:error, {:already_exist, _}} -> :ok
      error -> error
    end
  end

  defp add_memory_handler(config) do
    handler_config = %{
      level: config.level
    }

    case :logger.add_handler(:drops_handler, TestHandler, handler_config) do
      :ok -> :ok
      {:error, {:already_exist, _}} -> :ok
      error -> error
    end
  end

  # Filter management for default handler

  defp add_operation_filter_to_default_handler do
    # Add a filter to the default handler to prevent operation logs from being duplicated
    filter_config = {&Drops.Logger.Filter.filter_operation_logs/2, :stop}

    case :logger.add_handler_filter(:default, :drops_operation_filter, filter_config) do
      :ok -> :ok
      {:error, {:already_exist, _}} -> :ok
      error -> error
    end
  end

  defp remove_operation_filter_from_default_handler do
    # Remove the operation filter from the default handler
    case :logger.remove_handler_filter(:default, :drops_operation_filter) do
      :ok -> :ok
      {:error, {:not_found, _}} -> :ok
      error -> error
    end
  end

  # Normalize formatter config to use specific formatter modules
  defp normalize_formatter_config(formatter_config) do
    case formatter_config do
      # Direct module reference
      module when is_atom(module) ->
        {module, %Drops.Logger.Formatter.Config{}}

      # Module with options tuple
      {module, opts} when is_atom(module) and is_list(opts) ->
        {module, struct(Drops.Logger.Formatter.Config, opts)}

      # Default fallback to string formatter
      _ ->
        {Drops.Logger.Formatter.String, %Drops.Logger.Formatter.Config{}}
    end
  end
end
