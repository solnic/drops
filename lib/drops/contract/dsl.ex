defmodule Drops.Contract.DSL do
  def required(name) do
    {:required, name}
  end

  def type(type, predicates \\ []) do
    [predicate(:type?, type) | Enum.map(predicates, &predicate/1)]
  end

  def predicate(name, args \\ []) do
    {:predicate, {name, args}}
  end
end
