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
  alias Drops.Predicates

  use Drops.Type

  defimpl Drops.Type.Validator, for: Primitive do
    def validate(type, value, opts) do
      apply_predicates(value, type.constraints, opts)
    end

    defp apply_predicates(value, {:and, predicates}, path: path) do
      apply_predicates(value, predicates, path: path)
    end

    defp apply_predicates(value, predicates, path: path) do
      Enum.reduce(predicates, {:ok, {path, value}}, &apply_predicate(&1, &2))
    end

    defp apply_predicate({:predicate, {name, args}}, {:ok, {path, value}}) do
      apply_args =
        case args do
          [arg] -> [arg, value]
          [] -> [value]
          arg -> [arg, value]
        end

      if apply(Predicates, name, apply_args) do
        {:ok, {path, value}}
      else
        {:error, {path, name, apply_args}}
      end
    end

    defp apply_predicate(_, {:error, _} = error) do
      error
    end
  end
end
