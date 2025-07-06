defmodule Drops.Logger.Formatter.String do
  @moduledoc """
  String formatter for Drops operations debug logging.

  This formatter produces human-readable string output with operation metadata.
  Only processes logs that have operation-related metadata.

  ## Format

  The output format is: `[level] message metadata`

  Where metadata includes operation and step information when available.

  ## Configuration

  The formatter accepts a `Drops.Logger.Formatter.Config` struct with options:

  * `colorize` - Whether to apply ANSI colors to output (default: true)
  * `add_newline` - Whether to add newlines to formatted output (default: true)
  """

  alias Drops.Logger.MetadataDumper
  alias Drops.Logger.Formatter.Config

  @doc """
  Formats a log event as a human-readable string.

  ## Parameters

  * `log_event` - The log event map from the logger
  * `config` - Formatter configuration struct

  ## Returns

  A formatted string if the log event has operation metadata, empty string otherwise.
  """
  @spec format(map(), Config.t()) :: String.t()
  def format(log_event, %Config{} = config) do
    level = Map.get(log_event, :level, :debug)
    message = extract_message(log_event)

    # Use configured metadata fields, defaulting to [:operation, :step]
    app_config = Application.get_env(:drops, :logger, [])
    metadata_fields = Keyword.get(app_config, :metadata, [:operation, :step])

    # Only colorize if enabled in config AND ANSI is available
    should_colorize = config.colorize && IO.ANSI.enabled?()
    metadata = extract_metadata(log_event, metadata_fields, should_colorize)

    formatted =
      if should_colorize do
        format_with_colors(level, message, metadata)
      else
        "[#{level}] #{message}#{metadata}"
      end

    if config.add_newline do
      formatted <> "\n"
    else
      formatted
    end
  end

  defp extract_message(log_event) do
    case Map.get(log_event, :msg) do
      {:string, message} when is_binary(message) ->
        message

      message when is_binary(message) ->
        message

      message when is_list(message) ->
        IO.iodata_to_binary(message)

      {format, args} when is_binary(format) and is_list(args) ->
        try do
          :io_lib.format(format, args) |> IO.iodata_to_binary()
        rescue
          _ -> inspect({format, args})
        end

      other ->
        inspect(other)
    end
  end

  defp extract_metadata(log_event, metadata_fields, colorize) do
    meta = Map.get(log_event, :meta, %{})

    metadata_fields
    |> Enum.filter(&Map.has_key?(meta, &1))
    |> Enum.map(fn field ->
      value = Map.get(meta, field)
      formatted_value = MetadataDumper.dump(value)

      # Apply colors to metadata when colorization is enabled
      formatted_entry =
        if colorize and should_colorize_as_error?(field) do
          # Error metadata gets red color
          "#{field}=#{IO.ANSI.red()}#{formatted_value}#{IO.ANSI.reset()}"
        else
          # Non-error metadata gets faint color when colorization is enabled
          if colorize do
            "#{IO.ANSI.faint()}#{field}=#{formatted_value}#{IO.ANSI.reset()}"
          else
            "#{field}=#{formatted_value}"
          end
        end

      formatted_entry
    end)
    |> case do
      [] -> ""
      metadata_parts -> " " <> Enum.join(metadata_parts, " ")
    end
  end

  defp should_colorize_as_error?(field) when is_atom(field) do
    field |> Atom.to_string() |> String.starts_with?("error")
  end

  defp should_colorize_as_error?(_field), do: false

  defp format_with_colors(level, message, metadata) do
    level_color = get_level_color(level)
    level_color <> "[#{level}]" <> IO.ANSI.reset() <> " #{message}#{metadata}"
  end

  defp get_level_color(:debug), do: IO.ANSI.cyan()
  defp get_level_color(:info), do: IO.ANSI.green()
  defp get_level_color(:warning), do: IO.ANSI.yellow()
  defp get_level_color(:error), do: IO.ANSI.red()
  defp get_level_color(_), do: ""
end
