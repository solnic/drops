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

  defmodule Sum do
    alias __MODULE__

    @type t :: %__MODULE__{}

    defstruct [:left, :right]

    defimpl String.Chars, for: Sum do
      def to_string(%Error.Sum{left: left, right: right}) do
        "#{left} or #{right}"
      end
    end
  end
end
