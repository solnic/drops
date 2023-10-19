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

  defmodule Set do
    alias __MODULE__

    @type t :: %__MODULE__{}

    defstruct [:errors]

    defimpl String.Chars, for: Set do
      def to_string(%Error.Set{errors: errors}) do
        Enum.map(errors, &Kernel.to_string/1) |> Enum.join(" and ")
      end
    end
  end

  defmodule Caster do
    alias __MODULE__

    @type t :: %__MODULE__{}

    defstruct [:error]

    defimpl String.Chars, for: Caster do
      def to_string(%Error.Caster{error: error}) do
        "cast error: #{Kernel.to_string(error)}"
      end
    end
  end
end
