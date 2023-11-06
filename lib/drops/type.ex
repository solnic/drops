defmodule Drops.Type do
  @moduledoc ~S"""
  Type behaviour
  """

  defmacro __using__(do: block) do
    quote do
      import Drops.Type
      import Drops.Type.DSL

      unquote(block)
    end
  end

  defmacro __using__(spec) do
    quote do
      import Drops.Type
      import Drops.Type.DSL

      deftype(
        primitive: Drops.Type.infer_primitive(unquote(spec), []),
        constraints: Drops.Type.infer_constraints(unquote(spec), [])
      )

      def new(attributes) do
        struct(__MODULE__, attributes)
      end

      def new(spec, opts) do
        %__MODULE__{
          primitive: infer_primitive(spec, opts),
          constraints: infer_constraints(spec, opts)
        }
      end

      defoverridable new: 1, new: 2
    end
  end

  defmacro deftype(primitive) when is_atom(primitive) do
    quote do
      deftype(
        primitive: unquote(primitive),
        constraints: type(unquote(primitive))
      )
    end
  end

  defmacro deftype(attributes) when is_list(attributes) do
    quote do
      @type t :: %__MODULE__{}

      defstruct(unquote(attributes))
    end
  end

  defmacro deftype(primitive, attributes) when is_atom(primitive) do
    all_attrs =
      [primitive: primitive, constraints: Drops.Type.infer_constraints(primitive, [])] ++
        attributes

    quote do
      deftype(unquote(all_attrs))
    end
  end

  def infer_primitive([], []), do: :any
  def infer_primitive(name, _opts) when is_atom(name), do: name
  def infer_primitive({:type, {name, _}}, _opts), do: name

  def infer_constraints([], []), do: []
  def infer_constraints(type, _opts) when is_atom(type), do: [predicate(:type?, [type])]

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
