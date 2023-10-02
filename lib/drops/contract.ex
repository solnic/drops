defmodule Drops.Contract do
  defmacro __using__(_opts) do
    quote do
      alias Drops.{Casters, Predicates}
      alias Drops.Contract.Key
      alias Drops.Contract.Schema
      alias Drops.Contract.Type

      import Drops.Contract
      import Drops.Contract.Runtime

      Module.register_attribute(__MODULE__, :schema, accumulate: false)
      Module.register_attribute(__MODULE__, :rules, accumulate: true)

      @before_compile Drops.Contract.Runtime

      def conform(data) do
        conform(data, schema())
      end

      def conform(data, %Schema{atomize: true} = schema) do
        conform(Schema.atomize(data, schema.keys), schema.plan)
      end

      def conform(data, %Schema{} = schema) do
        conform(data, schema.plan)
      end

      def conform(data, %Schema{} = schema, path: root) do
        case conform(data, schema) do
          {:ok, value} ->
            {:ok, {root, value}}

          {:error, errors} ->
            nest_errors(errors, root)
        end
      end

      def conform(data, plan) do
        results = Enum.map(plan, &step(data, &1)) |> List.flatten()
        schema_errors = Enum.reject(results, &is_ok/1)

        if length(schema_errors) == 0 do
          output = to_output(results)

          case apply_rules(output) do
            [] ->
              {:ok, output}

            rule_errors ->
              {:error, schema_errors ++ rule_errors}
          end
        else
          {:error, schema_errors}
        end
      end

      def step(data, {:and, [left, right]}) do
        case step(data, left) do
          {:ok, result} ->
            [{:ok, result}] ++ Enum.map(right, &step(data, &1))

          error ->
            error
        end
      end

      def validate(value, %Type.Cast{} = type, path: path) do
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

          {:error, {predicate, value}} ->
            {:error, {predicate, path, value}}
        end
      end

      def step(data, {:validate, key}) do
        validate(data, key)
      end

      def validate(data, %Key{presence: :required, path: path} = key) do
        if Key.present?(data, key) do
          validate(get_in(data, path), key.type, path: path)
        else
          {:error, {[], :has_key?, path}}
        end
      end

      def validate(data, %Key{presence: :optional, path: path} = key) do
        if Key.present?(data, key) do
          validate(get_in(data, path), key.type, path: path)
        else
          :ok
        end
      end

      def validate(value, %Type{constraints: constraints}, path: path) do
        validate(value, constraints, path: path)
      end

      def validate(value, %Schema{} = schema, path: path) do
        case validate(value, schema.constraints, path: path) do
          {:ok, {_, validated_value}} ->
            conform(validated_value, schema, path: path)

          error ->
            error
        end
      end

      def validate(value, predicates, path: path) when is_list(predicates) do
        apply_predicates(value, predicates, path: path)
      end

      def validate(value, {:and, predicates}, path: path) do
        validate(value, predicates, path: path)
      end

      def validate(value, %Type.Sum{} = type, path: path) do
        case validate(value, type.left, path: path) do
          {:ok, _} = success ->
            success

          {:error, _} ->
            validate(value, type.right, path: path)
        end
      end

      def validate(value, %Type.List{member_type: member_type} = type, path: path) do
        case validate(value, type.constraints, path: path) do
          {:ok, {_, members}} ->
            result = List.flatten(
              Enum.with_index(members, &validate(&1, member_type, path: path ++ [&2]))
            )

            errors = Enum.reject(result, &is_ok/1)

            if length(errors) == 0,
              do: {:ok, {path, result}},
              else: errors

          error ->
            error
        end
      end

      def apply_predicates(value, {:and, [left, %Schema{} = schema]}, path: path) do
        case apply_predicate(left, {:ok, {path, value}}) do
          {:ok, _} ->
            conform(value, schema, path: path)

          {:error, error} ->
            {:error, error}
        end
      end

      def apply_predicates(value, {:and, predicates}, path: path) do
        apply_predicates(value, predicates, path: path)
      end

      def apply_predicates(value, predicates, path: path) do
        Enum.reduce(predicates, {:ok, {path, value}}, &apply_predicate(&1, &2))
      end

      def apply_predicate({:predicate, {name, args}}, {:ok, {path, value}}) do
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

      def apply_predicate(_, {:error, _} = error) do
        error
      end

      def apply_rules(output) do
        Enum.map(rules(), fn name -> apply(__MODULE__, :rule, [name, output]) end)
        |> Enum.filter(fn
          :ok -> false
          _ -> true
        end)
      end

      def is_ok(:ok), do: true
      def is_ok({:ok, _}), do: true
      def is_ok(:error), do: false
      def is_ok({:error, _}), do: false

      def to_output(results) do
        Enum.reduce(results, %{}, fn result, acc ->
          case result do
            {:ok, {path, value}} ->
              if is_list(value),
                do: put_in(acc, path, map_list_results(value)),
                else: put_in(acc, path, value)

            {:ok, value} ->
              value

            :ok ->
              acc
          end
        end)
      end

      defp map_list_results(members) do
        Enum.map(members, fn member ->
          case member do
            {:ok, {_, value}} ->
              if is_list(value), do: map_list_results(value), else: value

            {:ok, value} ->
              if is_list(value), do: map_list_results(value), else: value

            value ->
              value
          end
        end)
      end

      defp nest_errors(errors, root) do
        Enum.map(errors, fn
          {:error, {path, name, args}} ->
            {:error, {root ++ path, name, args}}

          {:error, [] = error_list} ->
            {:error, nest_errors(error_list, root)}
        end)
      end
    end
  end

  defmodule Runtime do
    defmacro __before_compile__(_env) do
      quote do
        def schema, do: @schema

        def rules, do: @rules
      end
    end
  end

  defmacro schema(opts \\ [], do: block) do
    set_schema(__CALLER__, opts, block)
  end

  defmacro rule(name, input, do: block) do
    quote do
      Module.put_attribute(__MODULE__, :rules, unquote(name))

      def rule(unquote(name), unquote(input)), do: unquote(block)

      def rule(unquote(name), _), do: :ok

      defoverridable rule: 2
    end
  end

  defp set_schema(_caller, opts, block) do
    quote do
      alias Drops.Contract.Schema

      mod = __MODULE__

      import Drops.Contract.DSL

      Module.put_attribute(mod, :schema, Schema.new(unquote(block), unquote(opts)))

      import Drops.Contract.Runtime
    end
  end
end
