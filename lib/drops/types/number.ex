defmodule Drops.Types.Number do
  @moduledoc ~S"""
  Drops.Types.Number is a struct that represents a number type
  that can be either an integer or a float

  ## Examples
  """

  use(Drops.Type, union([:integer, :float]))

  @opts name: :number
end
