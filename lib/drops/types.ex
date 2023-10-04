defmodule Drops.Types do
  alias Drops.Types.{
    Type,
    Sum,
    List,
    Cast,
    Schema,
    Schema.Key
  }

  def new(%{} = spec, opts) do
    atomize = opts[:atomize] || false

    keys =
      Enum.map(spec, fn {{presence, name}, type_spec} ->
        %Key{path: [name], presence: presence, type: new(type_spec, opts)}
      end)

    %Schema{
      primitive: :map,
      constraints: infer_constraints({:type, {:map, []}}, opts),
      atomize: atomize,
      keys: keys
    }
  end

  def new([left, right], opts) do
    %Sum{left: new(left, opts), right: new(right, opts), opts: opts}
  end

  def new({:type, {:list, member_type}} = spec, opts)
      when is_tuple(member_type) or is_map(member_type) do
    %List{
      primitive: :list,
      constraints: infer_constraints(spec, opts),
      member_type: new(member_type, opts)
    }
  end

  def new({:cast, {input_type, output_type, cast_opts}}, opts) do
    %Cast{
      input_type: new(input_type, opts),
      output_type: new(output_type, opts),
      opts: cast_opts
    }
  end

  def new(spec, opts) do
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
