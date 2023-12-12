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
      case apply_predicates(data, constraints) do
        {:ok, members} ->
          results = Enum.map(members, &Validator.validate(member_type, &1))
          errors = Enum.reject(results, &is_ok/1)

          if Enum.empty?(errors),
            do: {:ok, {:list, results}},
            else: {:error, {:list, results}}

        {:error, result} ->
          {:error, {:list, result}}
      end
    end

    defp apply_predicates(value, predicates) do
      Enum.reduce(predicates, {:ok, value}, &apply_predicate(&1, &2))
    end

    defp apply_predicate({:predicate, {name, args}}, {:ok, value}) do
      apply_args =
        case args do
          [arg] -> [arg, value]
          [] -> [value]
          arg -> [arg, value]
        end

      if apply(Predicates, name, apply_args) do
        {:ok, value}
      else
        {:error, {value, predicate: name, args: apply_args}}
      end
    end

    defp apply_predicate(_, {:error, _} = error) do
      error
    end

    defp is_ok(results) when is_list(results), do: Enum.all?(results, &is_ok/1)
    defp is_ok(:ok), do: true
    defp is_ok({:ok, _}), do: true
    defp is_ok(:error), do: false
    defp is_ok({:error, _}), do: false
  end
end
