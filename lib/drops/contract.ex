defmodule Drops.Contract do
  defmacro __using__(_opts) do
    quote do
      alias Drops.Predicates

      import Drops.Contract
      import Drops.Contract.Runtime

      Module.register_attribute(__MODULE__, :schema, accumulate: false)

      @before_compile Drops.Contract.Runtime

      def conform(data) do
        conform(data, schema())
      end

      def conform(data, schema) do
        results = Enum.map(schema, &validate(data, &1))

        if Enum.all?(results, &is_ok/1) do
          {:ok, data}
        else
          {:error, Enum.reject(results, &is_ok/1)}
        end
      end

      def validate(data, {{:required, name}, schema}) when is_map(schema) do
        case conform(data[name], schema) do
          {:error, results} ->
            {:error, Enum.map(results, fn {:error, {predicate, key, value}} ->
              {predicate, [name, key], value}
            end)}

          {:ok, value} ->
            {:ok, value}
        end
      end

      def validate(data, {{:required, name}, predicates}) do
        if Map.has_key?(data, name) do
          value = data[name]

          case apply_predicates(value, predicates) do
            {:error, {predicate, value}} ->
              {:error, {predicate, name, value}}

            {:ok, value} ->
              {:ok, value}
          end
        else
          {:error, {:has_key?, name}}
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

      def is_ok({:ok, _}), do: true
      def is_ok({:error, _}), do: false
    end
  end

  defmodule Runtime do
    defmacro __before_compile__(_env) do
      quote do
        def schema, do: @schema
      end
    end
  end

  defmacro schema(do: block) do
    set_schema(__CALLER__, block)
  end

  defp set_schema(_caller, block) do
    quote do
      mod = __MODULE__

      import Drops.Contract.DSL

      Module.put_attribute(mod, :schema, unquote(block))

      import Drops.Contract.Runtime
    end
  end
end
