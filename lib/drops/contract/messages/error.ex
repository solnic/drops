defmodule Drops.Contract.Messages.Error do
  @moduledoc false
  alias __MODULE__

  @type t :: %__MODULE__{}

  defstruct [:path, :text, :meta]

  defimpl String.Chars, for: Error do
    def to_string(%Error{path: path, text: text}) do
      "#{Enum.join(path, ".")} #{text}"
    end
  end
end
