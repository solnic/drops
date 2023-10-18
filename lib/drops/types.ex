defmodule Drops.Types do
  @moduledoc ~S"""
  Drops.Types is a module that provides functions for creating type structs
  from DSL's type specs represented by plain tuples.
  """
  alias Drops.Types.{
    Type,
    Sum,
    List,
    Cast,
    Map,
    Map.Key
  }

  def from_spec(%{primitive: _} = type, _opts) do
    type
  end

  def from_spec(%{} = spec, opts) do
    atomize = opts[:atomize] || false

    keys =
      Enum.map(spec, fn {{presence, name}, type_spec} ->
        case type_spec do
          %{primitive: _} ->
            %Key{path: [name], presence: presence, type: type_spec}

          _ ->
            %Key{path: [name], presence: presence, type: from_spec(type_spec, opts)}
        end
      end)

    %Map{
      primitive: :map,
      constraints: infer_constraints({:type, {:map, []}}, opts),
      atomize: atomize,
      keys: keys
    }
  end

  def from_spec({:sum, {left, right}}, opts) do
    %Sum{left: from_spec(left, opts), right: from_spec(right, opts), opts: opts}
  end

  def from_spec({:type, {:list, member_type}} = spec, opts)
      when is_tuple(member_type) or is_map(member_type) do
    %List{
      primitive: :list,
      constraints: infer_constraints(spec, opts),
      member_type: from_spec(member_type, opts)
    }
  end

  def from_spec({:cast, {input_type, output_type, cast_opts}}, opts) do
    %Cast{
      input_type: from_spec(input_type, opts),
      output_type: from_spec(output_type, opts),
      opts: cast_opts
    }
  end

  def from_spec([left, right], opts) when is_tuple(left) and is_tuple(right) do
    %Sum{left: from_spec(left, opts), right: from_spec(right, opts), opts: opts}
  end

  def from_spec([left, right], opts) when is_map(left) and is_map(right) do
    %Sum{left: from_spec(left, opts), right: from_spec(right, opts), opts: opts}
  end

  def from_spec([left, right], opts) do
    %Sum{left: left, right: right, opts: opts}
  end

  def from_spec(spec, opts) do
    %Type{
      primitive: infer_primitive(spec, opts),
      constraints: infer_constraints(spec, opts)
    }
  end

  def infer_primitive({:type, {type, _}}, _opts) do
    type
  end

  def infer_constraints({:type, {:list, member_type}}, _opts)
      when is_tuple(member_type) or is_map(member_type) do
    [predicate(:type?, :list)]
  end

  def infer_constraints({:type, {type, predicates}}, _opts)
      when length(predicates) > 0 do
    {:and, [predicate(:type?, type) | Enum.map(predicates, &predicate/1)]}
  end

  def infer_constraints({:type, {type, []}}, _opts) do
    [predicate(:type?, type)]
  end

  def predicate({name, args}) do
    predicate(name, args)
  end

  def predicate(name) do
    predicate(name, [])
  end

  def predicate(name, args) do
    {:predicate, {name, args}}
  end
end
