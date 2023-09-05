defmodule Drops do
  defmodule Contract do
    defmacro __using__(_opts) do
      quote do
        alias Drops.Predicates

        import Drops.DSL

        def schema do
          @schema
        end

        def apply(data) do
          results = Enum.map(Enum.reverse(@schema), &validate(data, &1))

          if Enum.all?(results, &is_ok/1) do
            data
          else
            Enum.reject(results, &is_ok/1)
          end
        end

        def is_ok({:ok, _}), do: true
        def is_ok({:error, _}), do: false

        def validate(data, {:required, name, type, predicates}) do
          if Map.has_key?(data, name) do
            case Predicates.type?(type, data[name]) do
              {:ok, value} ->
                Enum.reduce(predicates, {:ok, value}, fn predicate, {:ok, value} ->
                  apply(Predicates, predicate, [value])
                end)

              error ->
                error
            end
          else
            {:error, {:has_key?, name}}
          end
        end
      end
    end
  end

  defmodule Predicates do
    def type?(:string, value) when is_binary(value), do: {:ok, value}
    def type?(:string, value), do: {:error, {:string?, value}}

    def type?(:integer, value) when is_integer(value), do: {:ok, value}
    def type?(:integer, value), do: {:error, {:integer?, value}}

    def filled?(value) when is_binary(value) do
      if value == "", do: {:error, {:filled?, value}}, else: {:ok, value}
    end
  end

  defmodule DSL do
    defmacro schema(do: body) do
      Module.register_attribute(__CALLER__.module, :schema, accumulate: true)

      quote do
        unquote(body)
      end
    end

    defmacro required(name, type, predicates \\ []) do
      required(__CALLER__.module, name, type, predicates)
    end

    defp required(source, name, type, predicates) do
      Module.put_attribute(source, :schema, {:required, name, type, predicates})
    end
  end
end
