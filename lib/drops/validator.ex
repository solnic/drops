defmodule Drops.Validator do
  @moduledoc false
  defmacro __using__(_opts) do
    quote do
      alias Drops.{Casters, Predicates}
      alias Drops.Types
      alias Drops.Types.Map.Key

      def validate(value, %Types.Cast{} = type, path: path) do
        %{input_type: input_type, output_type: output_type, opts: cast_opts} = type

        caster = cast_opts[:caster] || Casters

        case validate(value, input_type, path: path) do
          {:ok, _} ->
            casted_value =
              apply(
                caster,
                :cast,
                [input_type.primitive, output_type.primitive, value] ++ cast_opts
              )

            validate(casted_value, output_type, path: path)

          {:error, _} = error ->
            {:error, {:cast, error}}
        end
      end

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

      def validate(value, %Types.List{member_type: member_type} = type, path: path) do
        case validate(value, type.constraints, path: path) do
          {:ok, {_, members}} ->
            result =
              List.flatten(
                Enum.with_index(members, &validate(&1, member_type, path: path ++ [&2]))
              )

            errors = Enum.reject(result, &is_ok/1)

            if Enum.empty?(errors), do: {:ok, {path, result}}, else: {:error, errors}

          error ->
            error
        end
      end

      def validate(value, {:and, predicates}, path: path) do
        validate(value, predicates, path: path)
      end

      def validate(value, %{primitive: primitive, constraints: constraints} = type,
            path: path
          ) when primitive != :map do
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

      defp is_ok(:ok), do: true
      defp is_ok({:ok, _}), do: true
      defp is_ok(:error), do: false
      defp is_ok({:error, _}), do: false
    end
  end
end
