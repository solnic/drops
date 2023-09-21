defmodule Drops.Contract.Schema.Key do
  alias __MODULE__
  alias Drops.Contract.Schema

  defstruct [:path, :presence, :type, :predicates, children: []]

  def new(spec, opts, attrs) do
    Map.merge(
      %Key{},
      Enum.into(attrs, %{
        type: infer_type(spec, opts),
        predicates: infer_predicates(spec, opts)
      })
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

  defp infer_type({:type, {type, _}}, _opts) do
    type
  end

  defp infer_type(spec, opts) when is_list(spec) do
    Enum.map(spec, &infer_type(&1, opts))
  end

  defp infer_type({:cast, {input_type, output_type, cast_opts}}, opts) do
    {:cast,
     {{infer_type(input_type, opts), infer_predicates(input_type, opts), cast_opts},
      infer_type(output_type, opts)}}
  end

  defp infer_predicates({:cast, {_input_type, output_type, _cast_opts}}, opts) do
    infer_predicates(output_type, opts)
  end

  defp infer_predicates(spec, opts) when is_map(spec) do
    {:and, [predicate(:type?, :map), Schema.new(spec, opts)]}
  end

  defp infer_predicates(spec, opts) when is_list(spec) do
    {:or, Enum.map(spec, &infer_predicates(&1, opts))}
  end

  defp infer_predicates({:type, {:list, []}}, _opts) do
    [predicate(:type?, :list)]
  end

  defp infer_predicates({:type, {:list, member_type}}, opts) when not is_list(member_type) do
    {:and, [predicate(:type?, :list), {:each, infer_predicates(member_type, opts)}]}
  end

  defp infer_predicates({:type, {type, predicates}}, _opts) when length(predicates) > 0 do
    {:and, [predicate(:type?, type) | Enum.map(predicates, &predicate/1)]}
  end

  defp infer_predicates({:type, {type, []}}, _opts) do
    [predicate(:type?, type)]
  end

  defp predicate({name, args}) do
    predicate(name, args)
  end

  defp predicate(name) do
    predicate(name, [])
  end

  defp predicate(name, args) do
    {:predicate, {name, args}}
  end
end
