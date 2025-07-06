defmodule Drops.Logger.TestHandler do
  @moduledoc """
  Memory log handler for Drops operations debug logging in tests.

  This module provides a memory-based log handler for testing purposes only.
  For console and file logging, Drops uses built-in Erlang logger handlers
  with custom formatters for better performance and consistency.

  This handler uses the same formatters as other handlers and respects their
  configuration (string vs JSON formatting).

  ## Memory Handler

  When using `:memory` handler, logs can be retrieved and cleared:

      # Get all captured logs
      logs = Drops.Logger.TestHandler.get_logs()

      # Clear captured logs
      Drops.Logger.TestHandler.clear_logs()

  This is particularly useful for testing where you want to assert on log content.
  """

  @doc """
  Gets all captured logs when using memory handler.

  Returns an empty list if not using memory handler or no logs captured.
  """
  @spec get_logs() :: [String.t()]
  def get_logs do
    case :persistent_term.get({__MODULE__, :logs}, nil) do
      nil -> []
      logs -> Enum.reverse(logs)
    end
  end

  @doc """
  Clears all captured logs when using memory handler.
  """
  @spec clear_logs() :: :ok
  def clear_logs do
    :persistent_term.put({__MODULE__, :logs}, [])
    :ok
  end

  # Logger handler callbacks for memory handler only

  def adding_handler(config) do
    # Initialize memory storage for memory handler
    :persistent_term.put({__MODULE__, :logs}, [])
    {:ok, config}
  end

  def removing_handler(_config) do
    # Clean up memory storage
    try do
      :persistent_term.erase({__MODULE__, :logs})
    rescue
      _ -> :ok
    end

    :ok
  end

  def log(log_event, _config) do
    # Process all operation-related logs regardless of level
    if Drops.Logger.Formatter.is_operation_log?(log_event) do
      # Use the same formatter as other handlers
      {formatter_module, formatter_config} = get_formatter_config()
      formatted_message = formatter_module.format(log_event, formatter_config)

      # Only store if the formatter returned content (operation logs)
      if formatted_message != "" do
        current_logs = :persistent_term.get({__MODULE__, :logs}, [])
        :persistent_term.put({__MODULE__, :logs}, [formatted_message | current_logs])
      end
    end

    :ok
  end

  def changing_config(_set_or_update, _old_config, new_config) do
    # Re-validate configuration on changes
    adding_handler(new_config)
  end

  def filter_config(config) do
    # Remove internal state from config when fetched
    config
  end

  # Private functions

  defp get_formatter_config do
    # Get the formatter configuration from the application environment
    logger_config = Application.get_env(:drops, :logger)
    formatter_type = Keyword.get(logger_config, :formatter)

    # Use the same normalization logic as the main logger
    normalize_formatter_config(formatter_type)
  end

  # Use the same normalization logic as Drops.Logger
  defp normalize_formatter_config(formatter_config) do
    case formatter_config do
      # Direct module reference
      module when is_atom(module) ->
        {module, %Drops.Logger.Formatter.Config{add_newline: false}}

      # Module with options tuple
      {module, opts} when is_atom(module) and is_list(opts) ->
        {module,
         struct(Drops.Logger.Formatter.Config, Keyword.put(opts, :add_newline, false))}

      # Default fallback to string formatter
      _ ->
        {Drops.Logger.Formatter.String,
         %Drops.Logger.Formatter.Config{add_newline: false}}
    end
  end
end
