defmodule Drops.Predicates.Helpers do
  alias Drops.Predicates

  def apply_predicates(value, {:and, predicates}) do
    apply_predicates(value, predicates)
  end

  def apply_predicates(value, predicates) do
    Enum.reduce(predicates, {:ok, value}, &apply_predicate(&1, &2))
  end

  def apply_predicate({:predicate, {name, args}}, {:ok, value}) do
    apply_args =
      case args do
        [arg] -> [arg, value]
        [] -> [value]
        arg -> [arg, value]
      end

    if apply(Predicates, name, apply_args) do
      {:ok, value}
    else
      if is_list(value) do
        {:error, [input: value, predicate: name, args: apply_args]}
      else
        {:error, {value, predicate: name, args: apply_args}}
      end
    end
  end

  def apply_predicate(_, {:error, _} = error) do
    error
  end
end
