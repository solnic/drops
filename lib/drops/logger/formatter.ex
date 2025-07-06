defmodule Drops.Logger.Formatter.Config do
  @moduledoc """
  Configuration struct for Drops logger formatters.

  This struct centralizes formatter configuration options that are shared
  across different formatter implementations.

  ## Fields

  * `colorize` - Whether to apply ANSI colors to output (default: true)
  * `add_newline` - Whether to add newlines to formatted output (default: true)
  """

  @type t :: %__MODULE__{
          colorize: boolean(),
          add_newline: boolean()
        }

  defstruct colorize: true, add_newline: true

  @doc """
  Creates a new formatter config with the given options.

  ## Examples

      iex> Drops.Logger.Formatter.Config.new()
      %Drops.Logger.Formatter.Config{colorize: true, add_newline: true}

      iex> Drops.Logger.Formatter.Config.new(colorize: false)
      %Drops.Logger.Formatter.Config{colorize: false, add_newline: true}
  """
  @spec new(keyword()) :: t()
  def new(opts \\ []) do
    struct(__MODULE__, opts)
  end
end

defmodule Drops.Logger.Formatter do
  @moduledoc """
  Custom formatters for Drops operations debug logging.

  This module provides formatters that work with built-in Erlang logger handlers
  to format operation debug logs in different formats.

  ## Formatter Types

  * `Drops.Logger.Formatter.String` - Human-readable string format with message and metadata (default)
  * `Drops.Logger.Formatter.Structured` - JSON format with message and metadata as structured data

  ## Configuration

  Formatters can be configured in two ways:

      # Simple module reference
      formatter: Drops.Logger.Formatter.String

      # Module with options
      formatter: {Drops.Logger.Formatter.String, colorize: false, add_newline: true}

  ## Usage

  These formatters are used automatically by the Drops logger system when
  configuring built-in handlers for console and file logging.
  """

  @doc """
  Checks if a log event is operation-related.

  Returns true if the log event has operation metadata, false otherwise.
  This is a common utility function used by all formatters.
  """
  @spec is_operation_log?(map()) :: boolean()
  def is_operation_log?(log_event) do
    meta = Map.get(log_event, :meta, %{})
    Map.has_key?(meta, :operation)
  end
end
