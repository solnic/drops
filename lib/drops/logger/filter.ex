defmodule Drops.Logger.Filter do
  @moduledoc """
  Logger filters for Drops operations.

  This module provides filter functions that can be used with Erlang logger
  to control which log messages are processed by different handlers.
  """

  @doc """
  Filter function to stop operation-related logs from being processed.

  This filter is designed to be used with the default logger handler to prevent
  operation logs from being duplicated when the Drops debug handler is active.

  ## Parameters

  - `log_event` - The log event map from the logger
  - `_config` - Filter configuration (unused)

  ## Returns

  - `:stop` - If the log has operation-related metadata (should be filtered out)
  - `:ignore` - If the log should be processed normally by this handler

  ## Usage

  This filter is automatically applied to the default handler when the Drops
  debug handler is added to prevent duplicate log output.
  """
  def filter_operation_logs(log_event, _config) do
    if is_operation_log?(log_event) do
      :stop
    else
      :ignore
    end
  end

  # Private functions

  defp is_operation_log?(log_event) do
    meta = Map.get(log_event, :meta, %{})
    # Check if the log has operation-related metadata
    Map.has_key?(meta, :operation) or Map.has_key?(meta, :step)
  end
end
