defmodule Drops.Contract.DSL do
  def required(name) do
    {:required, name}
  end

  def optional(name) do
    {:optional, name}
  end

  def from(type) do
    {:coerce, type}
  end

  def type(type, predicates) when is_list(predicates) do
    [predicate(:type?, type) | Enum.map(predicates, &predicate/1)]
  end

  def type({:coerce, input_type}, output_type) when is_atom(output_type) do
    {:coerce, input_type, output_type, type(input_type), type(output_type)}
  end

  def type({:coerce, input_type}, output_type, predicates) do
    {:coerce, input_type, output_type, type(input_type), type(output_type, predicates)}
  end

  def type(type) when is_atom(type) do
    [predicate(:type?, type)]
  end

  def predicate(name, args \\ []) do
    {:predicate, {name, args}}
  end
end
