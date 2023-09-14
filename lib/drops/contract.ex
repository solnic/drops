defmodule Drops.Contract do
  defmacro __using__(_opts) do
    quote do
      alias Drops.{Coercions, Predicates}
      alias Drops.Contract.Schema
      alias Drops.Contract.Schema.Key

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

      def step(
            data,
            {:validate,
             %{type: {:coerce, {{input_type, input_predicates}, output_type}}} = key}
          ) do
        value = get_in(data, key.path)

        case apply_predicates(value, input_predicates) do
          {:ok, _} ->
            validate(
              Coercions.coerce(input_type, output_type, value),
              key.predicates,
              path: key.path
            )

          {:error, {predicate, value}} ->
            {:error, {predicate, key.path, value}}
        end
      end

      def step(data, {:validate, key}) do
        validate(data, key)
      end

      def validate(data, %Key{presence: :required, path: path} = key) do
        if Key.present?(data, key) do
          validate(get_in(data, path), key.predicates, path: path)
        else
          {:error, {:has_key?, path}}
        end
      end

      def validate(data, %Key{presence: :optional, path: path} = key) do
        if Key.present?(data, key) do
          validate(get_in(data, path), key.predicates, path: path)
        else
          :ok
        end
      end

      def validate(value, predicates, path: path) when is_list(predicates) do
        case apply_predicates(value, predicates) do
          {:error, {predicate, value}} ->
            {:error, {predicate, path, value}}

          {:ok, value} ->
            {:ok, {path, value}}
        end
      end

      def validate(value, {:and, predicates}, path: path) do
        validate(value, predicates, path: path)
      end

      def validate(value, {:or, [head | tail]}, path: path) do
        case validate(value, head, path: path) do
          {:ok, _} = success ->
            success

          {:error, _} = error ->
            if length(tail) > 0, do: validate(value, {:or, tail}, path: path), else: error
        end
      end

      def apply_predicates(value, predicates) do
        Enum.reduce(
          predicates,
          {:ok, value},
          fn {:predicate, {name, args}}, result ->
            case result do
              {:ok, _} ->
                case args do
                  [] ->
                    apply(Predicates, name, [value])

                  arg ->
                    apply(Predicates, name, [arg, value])
                end

              {:error, _} = error ->
                error
            end
          end
        )
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
              put_in(acc, path, value)

            :ok ->
              acc
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
      alias Drops.Contract.Schema

      mod = __MODULE__

      import Drops.Contract.DSL

      Module.put_attribute(mod, :schema, Schema.new(unquote(block), unquote(opts)))

      import Drops.Contract.Runtime
    end
  end
end
