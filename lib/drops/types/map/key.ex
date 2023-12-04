defmodule Drops.Types.Map.Key do
  @moduledoc false

  alias __MODULE__
  alias Drops.Type.Validator

  defstruct [:path, :presence, :type]

  defimpl Drops.Type.Validator, for: Key do
    def validate(type, data), do: Key.validate(type, data)
  end

  def validate(%Key{presence: presence, path: path} = key, data) do
    if present?(data, key) do
      nest_result(Validator.validate(key.type, get_in(data, path)), path)
    else
      case presence do
        :required -> {:error, {path, {data, [predicate: :has_key?, args: []]}}}
        :optional -> :ok
      end
    end
  end

  def stringify(key) do
    %Key{path: Enum.map(key.path, &to_string/1), presence: key.presence, type: key.type}
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

  defp nest_result({:error, {:list, results}}, root),
    do:
      {:error, {root, {:list, Enum.with_index(results, &nest_result(&1, root ++ [&2]))}}}

  defp nest_result(results, root) when is_list(results),
    do: Enum.map(results, &nest_result(&1, root))

  defp nest_result({outcome, {path, result}}, root) when is_list(path),
    do: {outcome, {root ++ path, result}}

  defp nest_result({outcome, value}, root), do: {outcome, {root, value}}
end
