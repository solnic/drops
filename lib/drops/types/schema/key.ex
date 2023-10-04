defmodule Drops.Types.Schema.Key do
  alias __MODULE__

  defstruct [:path, :presence, :type]

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
