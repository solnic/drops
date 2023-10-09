defmodule Drops.Types.List do
  @moduledoc ~S"""
  Drops.Types.List is a struct that represents a list type with a member type and optional
  constraints.

  ## Examples

      iex> Drops.Types.from_spec({:type, {:list, []}}, [])
      %Drops.Types.Type{primitive: :list, constraints: [predicate: {:type?, :list}]}

      iex> Drops.Types.from_spec({:type, {:list, {:type, {:integer, []}}}}, [])
      %Drops.Types.List{
        primitive: :list,
        constraints: [predicate: {:type?, :list}],
        member_type: %Drops.Types.Type{
          primitive: :integer,
          constraints: [predicate: {:type?, :integer}]
        }
      }
  """
  defstruct [:primitive, :constraints, :member_type]
end
