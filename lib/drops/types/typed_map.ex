defmodule Drops.Types.TypedMap do
  @moduledoc ~S"""
  Drops.Types.TypedMap is a struct that represents a map in which keys and/or
  values have a specified type.

  ## Examples

      iex> Drops.Type.Compiler.visit(
      ...>  {
      ...>     :type,
      ...>     {:map, [keys: {:type, {:integer, []}}, values: {:type, {:string, []}}]}
      ...>   },
      ...>   []
      ...> )
      Drops.Types.TypedMap{
        key_type: %Drops.Types.Primitive{
           primitive: :integer,
           constraints: [predicate: {:type?, [:integer]}],
           opts: []
        },
        value_type: %Drops.Types.Primitive{
          primitive: :string,
          constraints: [predicate: {:type?, [:string]}],
          opts: []
        },
        constraints: [predicate: {:type?, [:map]}],
        opts: []
      }

  """

  alias __MODULE__
  use Drops.Type do
    deftype(
      key_type: :any,
      value_type: :any,
      constraints: type(:map)
    )

    def new(predicates) when is_list(predicates) do
      {keys, values, predicates} =
        Enum.reduce(
          predicates,
          {:any, :any, [type?: [:map]]},
          fn
            {:keys, keys}, {_, values, predicates} -> {Drops.Type.Compiler.visit(keys, []), values, predicates}
            {:values, values}, {keys, _, predicates} -> {keys, Drops.Type.Compiler.visit(values, []), predicates}
            predicate, {keys, values, predicates} -> {keys, values, [predicate | predicates]}
          end
        )
      %TypedMap {
        key_type: keys,
        value_type: values,
        constraints: infer_constraints(Enum.reverse(predicates))
      }
    end

    defimpl Drops.Type.Validator do
      def validate(type, value) do
        with {:ok, value} <- Drops.Predicates.Helpers.apply_predicates(value, type.constraints) do
          {values, errors} =
            Enum.reduce(
              value,
              {[], []},
              fn {key, val}, {values, errors} ->
                with {:ok, key} <- Drops.Type.Validator.validate(type.key_type, key),
                     {:ok, _val} = result <- Drops.Type.Validator.validate(type.value_type, val) do
                  {[Drops.Types.Map.Key.nest_result(result, [key]) | values], errors}
                else
                  {:error, _} = err ->
                    {value, [Drops.Types.Map.Key.nest_result(err, [key]) | errors]}
                end
              end
            )
          if Enum.empty?(errors),
             do: {:ok, {:map, values}},
             else: {:error, {:map, errors}}
        else
          {:error, {value, meta}} ->
            {:error, Keyword.merge([input: value], meta)}

          error ->
            error
        end
      end
    end
  end
end
