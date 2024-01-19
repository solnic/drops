defmodule Drops.Type do
  @moduledoc ~S"""
  Type behaviour
  """

  alias __MODULE__

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
        primitive: Type.infer_primitive(unquote(spec)),
        constraints: Type.infer_constraints(unquote(spec))
      )

      def new(attributes) when is_list(attributes) do
        struct(__MODULE__, attributes)
      end

      def new(spec) do
        new(
          primitive: infer_primitive(spec),
          constraints: infer_constraints(spec)
        )
      end

      def new(spec, constraints) when is_list(constraints) do
        new(
          primitive: infer_primitive(spec),
          constraints: infer_constraints({:type, {spec, constraints}})
        )
      end

      defoverridable new: 1

      defimpl Drops.Type.Validator, for: __MODULE__ do
        def validate(type, value) do
          Drops.Predicates.Helpers.apply_predicates(value, type.constraints)
        end
      end
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
      alias __MODULE__

      @type t :: %__MODULE__{}

      defstruct(unquote(attributes))
    end
  end

  defmacro deftype(primitive, attributes) when is_atom(primitive) do
    all_attrs =
      [primitive: primitive, constraints: Type.infer_constraints(primitive)] ++
        attributes

    quote do
      deftype(unquote(all_attrs))
    end
  end

  def infer_primitive([]), do: :any
  def infer_primitive(name) when is_atom(name), do: name
  def infer_primitive({:type, {name, _}}), do: name

  def infer_constraints([]), do: []
  def infer_constraints(type) when is_atom(type), do: [predicate(:type?, [type])]

  def infer_constraints(predicates) when is_list(predicates) do
    Enum.map(predicates, &predicate/1)
  end

  def infer_constraints({:type, {type, predicates}}) when length(predicates) > 0 do
    {:and, [predicate(:type?, type) | Enum.map(predicates, &predicate/1)]}
  end

  def infer_constraints({:type, {type, []}}) do
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
