defmodule Drops.Contract do
  defmacro __using__(_opts) do
    quote do
      use Drops.Validator

      alias Drops.Types.Schema
      alias Drops.Types.Schema.Key

      import Drops.Contract
      import Drops.Contract.Runtime

      Module.register_attribute(__MODULE__, :schema, accumulate: false)
      Module.register_attribute(__MODULE__, :rules, accumulate: true)

      @before_compile Drops.Contract.Runtime

      def conform(data) do
        conform(data, schema())
      end

      def conform(data, %Schema{atomize: true} = schema) do
        conform(Schema.atomize(data, schema.keys), schema.keys)
      end

      def conform(data, %Schema{} = schema) do
        conform(data, schema.keys)
      end

      def conform(data, %Schema{} = schema, path: root) do
        case conform(data, schema) do
          {:ok, value} ->
            {:ok, {root, value}}

          {:error, errors} ->
            nest_errors(errors, root)
        end
      end

      def conform(data, keys) do
        results = Enum.map(keys, &validate(data, &1)) |> List.flatten()
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

      def validate(value, %Schema{} = schema, path: path) do
        case validate(value, schema.constraints, path: path) do
          {:ok, {_, validated_value}} ->
            conform(validated_value, schema, path: path)

          error ->
            error
        end
      end

      defp apply_predicates(value, {:and, [left, %Schema{} = schema]}, path: path) do
        case apply_predicate(left, {:ok, {path, value}}) do
          {:ok, _} ->
            conform(value, schema, path: path)

          {:error, error} ->
            {:error, error}
        end
      end

      defp apply_rules(output) do
        Enum.map(rules(), fn name -> apply(__MODULE__, :rule, [name, output]) end)
        |> Enum.filter(fn
          :ok -> false
          _ -> true
        end)
      end

      defp to_output(results) do
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
      alias Drops.Types

      mod = __MODULE__

      import Drops.Contract.DSL

      Module.put_attribute(mod, :schema, Types.new(unquote(block), unquote(opts)))

      import Drops.Contract.Runtime
    end
  end
end
