defmodule Drops.Contract.DSL do
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
