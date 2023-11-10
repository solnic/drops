defmodule Drops.Types.Map.Key do
  @moduledoc false

  alias __MODULE__

  defstruct [:path, :presence, :type]

  defimpl Drops.Type.Validator, for: Key do
    def validate(type, data), do: Key.validate(type, data)
  end

  def validate(%Key{presence: :required, path: path} = key, data) do
    if Key.present?(data, key) do
      case Drops.Type.Validator.validate(key.type, get_in(data, path)) do
        {:ok, value} ->
          {:ok, {path, value}}

        {:error, {value, meta}} ->
          {:error, {path, {value, meta}}}

        {:error, error} ->
          {:error, {path, error}}

        results ->
          Enum.map(results, &nest_result(&1, path))
      end
    else
      {:error, {path, {data, [predicate: :has_key?, args: []]}}}
    end
  end

  def validate(%Key{presence: :optional, path: path} = key, data) do
    if Key.present?(data, key) do
      case Drops.Type.Validator.validate(key.type, get_in(data, path)) do
        {:ok, value} ->
          {:ok, {path, value}}

        {:error, {value, meta}} ->
          {:error, {path, {value, meta}}}

        {:error, error} ->
          {:error, {path, error}}

        results ->
          Enum.map(results, &nest_result(&1, path))
      end
    else
      :ok
    end
  end

  def nest_result(results, root) when is_list(results) do
    Enum.map(results, &nest_result(&1, root))
  end

  def nest_result({:ok, {path, value}}, root), do: {:ok, {root ++ path, value}}

  def nest_result({:error, {path, result}}, root),
    do: {:error, {root ++ path, result}}

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
end
