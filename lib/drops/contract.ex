defmodule Drops.Contract do
  defmacro __using__(_opts) do
    quote do
      alias Drops.{Coercions, Predicates}

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
          {:ok, to_output(results)}
        else
          {:error, Enum.reject(results, &is_ok/1)}
        end
      end

      def validate(data, {{:required, name}, predicates}) do
        if Map.has_key?(data, name) do
          validate(data[name], predicates, path: name)
        else
          {:error, {:has_key?, name}}
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

      def validate(value, schema, path: path) when is_map(schema) do
        case Predicates.type?(:map, value) do
          {:ok, value} ->
            case conform(value, schema) do
              {:error, results} ->
                {:error, Enum.map(results, &nest_error(path, &1))}

              {:ok, value} ->
                {:ok, {path, value}}
            end

          {:error, {predicate, value}} ->
            {:error, {predicate, path, value}}
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

      def nest_error(name, errors) when is_list(errors) do
        Enum.map(errors, &nest_error(name, &1))
      end

      def nest_error(name, {:error, errors}) do
        nest_error(name, errors)
      end

      def nest_error(name, {predicate, path, value}) when is_list(path) do
        {predicate, [name] ++ path, value}
      end

      def nest_error(name, {predicate, key, value}) when is_atom(key) do
        {predicate, [name, key], value}
      end

      def to_output(results) do
        Enum.reduce(results, %{}, fn {:ok, {path, value}}, acc ->
          put_in(acc, List.flatten([path]), value)
        end)
      end
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
