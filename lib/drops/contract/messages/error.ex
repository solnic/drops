defmodule Drops.Contract.Messages.Error do
  alias __MODULE__

  defprotocol Conversions do
    @doc """
    Protocol for error conversions
    """

    @spec nest(error :: map(), root :: list()) :: map()
    def nest(error, root)
  end

  defmodule Type do
    @moduledoc false
    @type t :: %__MODULE__{}

    defstruct [:path, :text, :meta]

    defimpl String.Chars, for: Error.Type do
      def to_string(%Error.Type{path: path, text: text}) do
        String.trim("#{Enum.join(path, ".")} #{text}")
      end
    end

    defimpl Error.Conversions, for: Error.Type do
      def nest(%Error.Type{path: path} = error, root) do
        Map.merge(error, %{path: root ++ path})
      end
    end
  end

  defmodule Sum do
    @type t :: %__MODULE__{}

    defstruct [:left, :right]

    defimpl String.Chars, for: Sum do
      def to_string(%Error.Sum{left: left, right: right}) do
        "#{left} or #{right}"
      end
    end

    defimpl Error.Conversions, for: Sum do
      def nest(%Error.Sum{left: left, right: right} = error, root) do
        Map.merge(error, %{left: Error.Conversions.nest(left, root), right: Error.Conversions.nest(right, root)})
      end
    end
  end

  defmodule Set do
    @type t :: %__MODULE__{}

    defstruct [:errors]

    defimpl String.Chars, for: Error.Set do
      def to_string(%Error.Set{errors: errors}) do
        Enum.map(errors, &Kernel.to_string/1) |> Enum.join(" and ")
      end
    end

    defimpl Error.Conversions, for: Error.Set do
      def nest(%Error.Set{errors: errors} = error, root) do
        Map.merge(error, %{errors: Enum.map(errors, &Error.Conversions.nest(&1, root))})
      end
    end
  end

  defmodule Caster do
    @type t :: %__MODULE__{}

    defstruct [:error]

    defimpl String.Chars, for: Error.Caster do
      def to_string(%Error.Caster{error: error}) do
        "cast error: #{Kernel.to_string(error)}"
      end
    end

    defimpl Error.Conversions, for: Error.Caster do
      def nest(%Error.Caster{error: error} = caster_error, root) do
        Map.merge(caster_error, %{error: Error.Conversions.nest(error, root)})
      end
    end
  end
end
