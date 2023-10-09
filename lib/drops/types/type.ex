defmodule Drops.Types.Type do
  @moduledoc ~S"""
  Drops.Types.Type is a struct that represents a primitive type with optional constraints.

  ## Examples

      iex> Drops.Types.from_spec({:type, {:string, []}}, [])
      %Drops.Types.Type{
        primitive: :string,
        constraints: [predicate: {:type?, :string}]
      }

      iex> Drops.Types.from_spec({:type, {:string, [:filled?]}}, [])
      %Drops.Types.Type{
        primitive: :string,
        constraints: {:and, [predicate: {:type?, :string}, predicate: {:filled?, []}]}
      }

  """
  defstruct [:primitive, :constraints]
end
