defmodule Drops.Types.Sum do
  @moduledoc ~S"""
  Drops.Types.Sum is a struct that represents a sum type with left and right types.

  ## Examples

      iex> Drops.Type.Compiler.visit([{:type, {:string, []}}, {:type, {:integer, []}}], [])
      %Drops.Types.Sum{
        left: %Drops.Types.Primitive{
          primitive: :string,
          constraints: [predicate: {:type?, :string}]
        },
        right: %Drops.Types.Primitive{
          primitive: :integer,
          constraints: [predicate: {:type?, :integer}]
        },
        opts: []
      }

  """
  use Drops.Type do
    deftype [:left, :right, :opts]

    def new(left, right) when is_struct(left) and is_struct(right) do
      struct(__MODULE__, left: left, right: right)
    end
  end
end
