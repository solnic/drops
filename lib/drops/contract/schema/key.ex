defmodule Drops.Contract.Schema.Key do
  alias __MODULE__
  alias Drops.Contract.Schema

  defstruct [:path, :presence, :type, :predicates, children: []]

  def new(spec, attrs) do
    Map.merge(
      %Key{},
      Enum.into(attrs, %{type: infer_type(spec), predicates: infer_predicates(spec)})
    )
  end

  def present?(map, _) when not is_map(map) do
    true
  end

  def present?(_map, []) do
    true
  end

  def present?(map, %Key{} = key) do
    present?(map, key.path)
  end

  def present?(map, [key | tail]) do
    Map.has_key?(map, key) and present?(map[key], tail)
  end

  defp infer_type({:type, {type, _}}) do
    type
  end

  defp infer_type(spec) when is_list(spec) do
    Enum.map(spec, &infer_type/1)
  end

  defp infer_type({:coerce, {input_type, output_type}}) do
    {:coerce, {{infer_type(input_type), infer_predicates(input_type)}, infer_type(output_type)}}
  end

  defp infer_predicates({:coerce, {_input_type, output_type}}) do
    infer_predicates(output_type)
  end

  defp infer_predicates(spec) when is_map(spec) do
    {:and, [predicate(:type?, :map), Schema.new(spec, [])]}
  end

  defp infer_predicates(spec) when is_list(spec) do
    {:or, Enum.map(spec, &infer_predicates/1)}
  end

  defp infer_predicates({:type, {:list, []}}) do
    [predicate(:type?, :list)]
  end

  defp infer_predicates({:type, {:list, member_type}}) do
    {:and, [predicate(:type?, :list), {:each, infer_predicates(member_type)}]}
  end

  defp infer_predicates({:type, {type, predicates}}) when length(predicates) > 0 do
    {:and, [predicate(:type?, type) | Enum.map(predicates, &predicate/1)]}
  end

  defp infer_predicates({:type, {type, []}}) do
    [predicate(:type?, type)]
  end

  defp predicate(name, args) do
    {:predicate, {name, args}}
  end

  defp predicate(name) do
    {:predicate, {name, []}}
  end
end
