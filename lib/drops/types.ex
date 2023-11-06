defmodule Drops.Types do
  @moduledoc ~S"""
  Drops.Types is a module that provides functions for creating type structs
  from DSL's type specs represented by plain tuples.
  """
  alias Drops.Types.{
    Primitive,
    Sum,
    List,
    Cast,
    Map,
    Map.Key
  }

  def from_spec(type, _opts) when is_struct(type), do: type

  def from_spec(%{} = spec, opts) do
    keys =
      Enum.map(spec, fn {{presence, name}, type_spec} ->
        %Key{path: [name], presence: presence, type: from_spec(type_spec, opts)}
      end)

    Map.new(keys, opts)
  end

  def from_spec({:sum, {left, right}}, opts) do
    Sum.new(from_spec(left, opts), from_spec(right, opts))
  end

  def from_spec({:type, {:list, member_type}}, opts)
      when is_tuple(member_type) or is_map(member_type) do
    List.new(from_spec(member_type, opts))
  end

  def from_spec({:cast, {input_type, output_type, cast_opts}}, opts) do
    Cast.new(from_spec(input_type, opts), from_spec(output_type, opts), cast_opts)
  end

  def from_spec([left, right], opts) when is_tuple(left) and is_tuple(right) do
    Sum.new(from_spec(left, opts), from_spec(right, opts))
  end

  def from_spec([left, right], opts) when is_map(left) and is_map(right) do
    Sum.new(from_spec(left, opts), from_spec(right, opts))
  end

  def from_spec([left, right], _opts) do
    Sum.new(left, right)
  end

  def from_spec(mod, opts) when is_atom(mod) do
    mod.new(opts)
  end

  def from_spec(spec, opts) when is_tuple(spec) do
    Primitive.new(spec, opts)
  end
end
