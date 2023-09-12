defmodule Drops.Predicates do
  def type?(:string, value) when is_binary(value), do: {:ok, value}
  def type?(:string, value), do: {:error, {:string?, value}}

  def type?(:integer, value) when is_integer(value), do: {:ok, value}
  def type?(:integer, value), do: {:error, {:integer?, value}}

  def type?(:map, value) when is_map(value), do: {:ok, value}
  def type?(:map, value), do: {:error, {:map?, value}}

  def type?(:date_time, %DateTime{} = value), do: {:ok, value}
  def type?(:date_time, value), do: {:error, {:date_time?, value}}

  def filled?(value) when is_binary(value) do
    if value == "", do: {:error, {:filled?, value}}, else: {:ok, value}
  end
end
