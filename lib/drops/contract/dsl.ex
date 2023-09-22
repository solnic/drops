defmodule Drops.Contract.DSL do
  def required(name) do
    {:required, name}
  end

  def optional(name) do
    {:optional, name}
  end

  def from(type, cast_opts \\ []) do
    {:cast, {type, cast_opts}}
  end

  def type([list: members]) when is_map(members) or is_tuple(members) do
    {:type, {:list, members}}
  end

  def type([list: [type | predicates]]) do
    {:type, {:list, type(type, predicates)}}
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

  def type({:cast, {input_type, cast_opts}}, output_type) do
    {:cast, {type(input_type), type(output_type), cast_opts}}
  end

  def list(members) when is_map(members) or is_tuple(members) do
    type(list: members)
  end

  def list(type, predicates \\ []) when is_list(predicates) do
    type(list: [type | predicates])
  end

  def maybe(type, predicates \\ []) do
    type([:nil, [{type, predicates}]])
  end

  def string() do
    type(:string)
  end

  def string(predicate) when is_atom(predicate) do
    string([predicate])
  end

  def string(predicates) when is_list(predicates) do
    type(:string, predicates)
  end
end
