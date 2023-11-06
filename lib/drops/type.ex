defmodule Drops.Type do
  @moduledoc ~S"""
  Type behaviour
  """

  defmacro __using__(spec) do
    quote do
      import Drops.Type
      import Drops.Type.DSL

      @type t :: %__MODULE__{}

      defstruct [:primitive, :constraints]

      @__spec__ unquote(spec)

      def new(opts) do
        %__MODULE__{
          primitive: infer_primitive(@__spec__, opts),
          constraints: infer_constraints(@__spec__, opts)
        }
      end
    end
  end

  def infer_primitive({:type, {type, _}}, _opts) do
    type
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
