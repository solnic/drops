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

        def validate(data, {:required, name, type}) do
          if Map.has_key?(data, name) do
            Predicates.type?(type, data[name])
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
  end

  defmodule DSL do
    defmacro schema(do: body) do
      Module.register_attribute(__CALLER__.module, :schema, accumulate: true)

      quote do
        unquote(body)
      end
    end

    defmacro required(name, type) do
      required(__CALLER__.module, name, type)
    end

    defp required(source, name, type) do
      Module.put_attribute(source, :schema, {:required, name, type})
    end
  end
end
