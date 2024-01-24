defmodule Drops.Validator.Messages.Error do
  @moduledoc false

  alias __MODULE__

  defprotocol Conversions do
    @moduledoc false

    @spec nest(error :: map(), root :: list()) :: map()
    def nest(error, root)
  end

  defmodule Type do
    @moduledoc false
    @type t :: %__MODULE__{}

    defstruct [:path, :text, :meta]
  end

  defmodule Key do
    @moduledoc false
    @type t :: %__MODULE__{}

    defstruct [:path, :text, :meta]
  end

  defimpl String.Chars, for: [Error.Type, Error.Key] do
    def to_string(%{path: [], text: text}), do: text

    def to_string(%{path: path, text: text}) do
      "#{Enum.join(path, ".")} #{text}"
    end
  end

  defimpl Error.Conversions, for: [List] do
    def nest(errors, root) do
      Enum.map(errors, &Error.Conversions.nest(&1, root))
    end
  end

  defimpl Error.Conversions, for: [Error.Type, Error.Key] do
    def nest(%{path: path} = error, root) do
      Map.merge(error, %{path: root ++ path})
    end
  end

  defmodule Sum do
    @moduledoc false
    @type t :: %__MODULE__{}

    defstruct [:left, :right]

    defimpl String.Chars, for: Sum do
      def to_string(%Error.Sum{left: left, right: right})
          when is_list(left) and is_list(right) do
        "#{Enum.map(left, &Kernel.to_string/1)} or #{Enum.map(right, &Kernel.to_string/1)}"
      end

      def to_string(%Error.Sum{left: left, right: right}) when is_list(left) do
        "#{Enum.map(left, &Kernel.to_string/1)} or #{right}"
      end

      def to_string(%Error.Sum{left: left, right: right}) when is_list(right) do
        "#{left} or #{Enum.map(right, &Kernel.to_string/1)}"
      end

      def to_string(%Error.Sum{left: left, right: right}) do
        "#{left} or #{right}"
      end
    end

    defimpl Error.Conversions, for: Sum do
      def nest(%Error.Sum{left: left, right: right} = error, root) do
        Map.merge(error, %{
          left: Error.Conversions.nest(left, root),
          right: Error.Conversions.nest(right, root)
        })
      end
    end
  end

  defmodule Set do
    @moduledoc false
    @type t :: %__MODULE__{}

    defstruct [:errors]

    defimpl String.Chars, for: Error.Set do
      def to_string(%Error.Set{errors: errors}) do
        Enum.map(errors, fn e ->
          if is_list(e), do: Enum.map(e, &Kernel.to_string/1), else: Kernel.to_string(e)
        end)
        |> List.flatten()
        |> Enum.join(" and ")
      end
    end

    defimpl Error.Conversions, for: Error.Set do
      def nest(%Error.Set{errors: errors} = error, root) do
        Map.merge(error, %{errors: Enum.map(errors, &Error.Conversions.nest(&1, root))})
      end
    end
  end

  defmodule Caster do
    @moduledoc false
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

  defmodule Rule do
    @moduledoc false
    @type t :: %__MODULE__{}

    defstruct [:text, path: []]

    defimpl String.Chars, for: Error.Rule do
      def to_string(%Error.Rule{text: text, path: path}) when length(path) == 0 do
        text
      end

      def to_string(%Error.Rule{text: text, path: path}) do
        "#{Enum.join(path, ".")} #{text}"
      end
    end

    defimpl Error.Conversions, for: Error.Rule do
      def nest(%Error.Rule{path: path} = error, root) do
        Map.merge(error, %{path: root ++ path})
      end
    end
  end
end
