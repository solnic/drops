defmodule Drops.Contract do

  defmacro __using__(_opts) do
    quote do
      alias Drops.Predicates

      import Drops.Contract.DSL

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
          value = data[name]

          case Predicates.type?(type, value) do
            {:ok, value} ->
              case apply_predicates(value, predicates) do
                {:error, {predicate, value}} ->
                  {:error, {predicate, name, value}}

                {:ok, value} ->
                  {:ok, value}
              end

            error ->
              error
          end
        else
          {:error, {:has_key?, name}}
        end
      end

      def apply_predicates(value, predicates) do
        Enum.reduce(
          predicates,
          {:ok, value},
          fn predicate, {:ok, value} -> apply(Predicates, predicate, [value]) end
        )
      end
    end
  end
end
