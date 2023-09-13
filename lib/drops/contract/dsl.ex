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

  def type({type, predicates}) when is_atom(type) do
    type(type, predicates)
  end

  def type(types) when is_list(types) do
    Enum.map(types, &type/1)
  end

  def type(type) do
    {:type, {type, []}}
  end

  def type(type, predicates) when is_list(predicates) do
    {:type, {type, predicates}}
  end

  def type({:coerce, input_type}, output_type) do
    {:coerce, {type(input_type), type(output_type)}}
  end
end
