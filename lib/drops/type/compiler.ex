defmodule Drops.Type.Compiler do
  @moduledoc ~S"""
  Drops.Type.Compiler is a module that provides functions for creating type structs
  from DSL's type specs represented by plain tuples.
  """
  alias Drops.Types.{
    Primitive,
    Union,
    Number,
    List,
    Cast,
    Map,
    Map.Key
  }

  @primitives [
    :any,
    :atom,
    :boolean,
    :date,
    :date_time,
    :float,
    :integer,
    :list,
    :map,
    :nil,
    :string,
    :time
  ]

  def visit(type, _opts) when is_struct(type), do: type

  def visit(%{} = spec, opts) do
    keys =
      Enum.map(spec, fn {{presence, name}, type_spec} ->
        %Key{path: [name], presence: presence, type: visit(type_spec, opts)}
      end)

    Map.new(keys, opts)
  end

  def visit({:union, {left, right}}, opts) do
    Union.new(visit(left, opts), visit(right, opts))
  end

  def visit({:type, {:number, predicates}}, opts) do
    Number.new(predicates, opts)
  end

  def visit({:type, {:list, member_type}}, opts)
      when is_tuple(member_type) or is_map(member_type) do
    List.new(visit(member_type, opts))
  end

  def visit({:type, {:list, predicates}}, opts) do
    List.new(visit({:type, {:any, []}}, opts), predicates)
  end

  def visit({:cast, {input_type, output_type, cast_opts}}, opts) do
    Cast.new(visit(input_type, opts), visit(output_type, opts), cast_opts)
  end

  def visit([left, right], opts) when is_tuple(left) and is_tuple(right) do
    Union.new(visit(left, opts), visit(right, opts))
  end

  def visit([left, right], opts) when is_map(left) and is_map(right) do
    Union.new(visit(left, opts), visit(right, opts))
  end

  def visit([left, right], _opts) do
    Union.new(left, right)
  end

  def visit({:type, {type, predicates}}, opts)
      when is_atom(type) and type not in @primitives do
    type.new(predicates, opts)
  end

  def visit(type, opts) when is_atom(type) and type not in @primitives do
    type.new(opts)
  end

  def visit(spec, _opts) do
    Primitive.new(spec)
  end
end
