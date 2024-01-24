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

  alias Drops.Predicates
  alias Drops.Type.Validator

  use Drops.Type do
    deftype(:list, member_type: nil)

    def new(member_type, constraints \\ []) when is_struct(member_type) do
      struct(__MODULE__,
        member_type: member_type,
        constraints: Drops.Type.infer_constraints(:list) ++ infer_constraints(constraints)
      )
    end
  end

  defimpl Validator, for: List do
    def validate(%{constraints: constraints, member_type: member_type}, data) do
      case Predicates.Helpers.apply_predicates(data, constraints) do
        {:ok, members} ->
          results = Enum.map(members, &Validator.validate(member_type, &1))
          errors = Enum.reject(results, &Predicates.Helpers.is_ok/1)

          if Enum.empty?(errors),
            do: {:ok, {:list, results}},
            else: {:error, {:list, results}}

        result ->
          result
      end
    end
  end
end
