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
        conform(Schema.atomize(data, schema), schema)
      end

      def conform(data, schema) do
        results = Enum.map(schema.plan, &step(data, &1)) |> List.flatten() |> apply_rules()

        if Enum.all?(results, &is_ok/1) do
          {:ok, to_output(results)}
        else
          {:error, Enum.reject(results, &is_ok/1)}
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

      def validate(
            value,
            {:coerce, input_type, output_type, input_predicates, output_predicates},
            path: name
          ) do
        case apply_predicates(value, input_predicates) do
          {:ok, _} ->
            validate(
              Coercions.coerce(input_type, output_type, value),
              output_predicates,
              path: name
            )

          {:error, {predicate, value}} ->
            {:error, {predicate, name, value}}
        end
      end

      def apply_predicates(value, predicates) do
        Enum.reduce(
          predicates,
          {:ok, value},
          fn {:predicate, {name, args}}, {:ok, value} ->
            case args do
              [] ->
                apply(Predicates, name, [value])

              arg ->
                apply(Predicates, name, [arg, value])
            end
          end
        )
      end

      def apply_rules(results) do
        (results ++
           Enum.map(rules(), fn name -> apply(__MODULE__, :rule, [name, results]) end))
        |> Enum.filter(fn
          :ok -> false
          _ -> true
        end)
      end

      def is_ok({:ok, _}), do: true
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
