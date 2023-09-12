defmodule Drops.Coercions do
  def coerce(:string, :integer, value), do: String.to_integer(value)

  def coerce(:string, :float, value) do
    {float, _} = Float.parse(value)
    float
  end

  def coerce(:integer, :string, value), do: to_string(value)
end
