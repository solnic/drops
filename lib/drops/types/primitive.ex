defmodule Drops.Types.Primitive do
  @moduledoc ~S"""
  Drops.Types.Primitive is a struct that represents a primitive type with optional constraints.

  ## Examples

      iex> Drops.Type.Compiler.visit({:type, {:string, []}}, [])
      %Drops.Types.Primitive{
        primitive: :string,
        constraints: [predicate: {:type?, :string}]
      }

      iex> Drops.Type.Compiler.visit({:type, {:string, [:filled?]}}, [])
      %Drops.Types.Primitive{
        primitive: :string,
        constraints: {:and, [predicate: {:type?, :string}, predicate: {:filled?, []}]}
      }

  """
  use Drops.Type
end
