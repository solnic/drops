defmodule Drops.Types.List do
  @moduledoc ~S"""
  Drops.Types.List is a struct that represents a list type with a member type and optional
  constraints.

  ## Examples

      iex> Drops.Type.Compiler.visit({:type, {:list, []}}, [])
      %Drops.Types.Primitive{primitive: :list, constraints: [predicate: {:type?, :list}]}

      iex> Drops.Type.Compiler.visit({:type, {:list, {:type, {:integer, []}}}}, [])
      %Drops.Types.List{
        primitive: :list,
        constraints: [predicate: {:type?, :list}],
        member_type: %Drops.Types.Primitive{
          primitive: :integer,
          constraints: [predicate: {:type?, :integer}]
        }
      }
  """
  use Drops.Type do
    deftype :list, [member_type: nil]

    def new(member_type) when is_struct(member_type) do
      struct(__MODULE__, member_type: member_type)
    end
  end
end
