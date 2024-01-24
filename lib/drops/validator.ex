defmodule Drops.Validator do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      alias Drops.{Casters, Predicates}
      alias Drops.Types
      alias Drops.Types.Map.Key

      def validate(data, %Types.Map{} = type, path: path) do
        case Drops.Type.Validator.validate(type, data) do
          {:ok, value} ->
            {:ok, {path, value}}

          {:error, {value, meta}} ->
            {:error, {path, {value, meta}}}
        end
      end

      def validate(data, keys) when is_list(keys) do
        Enum.map(keys, &Drops.Type.Validator.validate(&1, data)) |> List.flatten()
      end

      def validate(value, {:and, predicates}, path: path) do
        validate(value, predicates, path: path)
      end

      def validate(value, %{primitive: primitive, constraints: constraints} = type,
            path: path
          )
          when primitive != :map do
        apply_predicates(value, constraints, path: path)
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

      defp ok?(results) when is_list(results), do: Enum.all?(results, &ok?/1)
      defp ok?(:ok), do: true
      defp ok?({:ok, _}), do: true
      defp ok?(:error), do: false
      defp ok?({:error, _}), do: false
    end
  end
end
