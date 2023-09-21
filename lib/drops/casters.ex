defmodule Drops.Casters do
  def cast(:string, :integer, value), do: String.to_integer(value)

  def cast(:string, :float, value) do
    {float, _} = Float.parse(value)
    float
  end

  def cast(:integer, :string, value), do: to_string(value)
end
