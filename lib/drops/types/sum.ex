defmodule Drops.Types.Sum do
  @moduledoc ~S"""
  Drops.Types.Sum is a struct that represents a sum type with left and right types.

  ## Examples

      iex> Drops.Types.from_spec([{:type, {:string, []}}, {:type, {:integer, []}}], [])
      %Drops.Types.Sum{
        left: %Drops.Types.Type{
          primitive: :string,
          constraints: [predicate: {:type?, :string}]
        },
        right: %Drops.Types.Type{
          primitive: :integer,
          constraints: [predicate: {:type?, :integer}]
        },
        opts: []
      }

  """
  defstruct [:left, :right, :opts]
end
