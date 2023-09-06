defmodule Drops.Predicates do
  def type?(:string, value) when is_binary(value), do: {:ok, value}
  def type?(:string, value), do: {:error, {:string?, value}}

  def type?(:integer, value) when is_integer(value), do: {:ok, value}
  def type?(:integer, value), do: {:error, {:integer?, value}}

  def filled?(value) when is_binary(value) do
    if value == "", do: {:error, {:filled?, value}}, else: {:ok, value}
  end
end
