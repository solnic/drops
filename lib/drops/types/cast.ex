defmodule Drops.Types.Cast do
  @moduledoc ~S"""
  Drops.Types.Cast is a struct that represents a cast type with input and output types.

  ## Examples

      iex> Drops.Types.from_spec(
      ...>   {:cast, {{:type, {:integer, []}}, {:type, {:date_time, []}}, [:miliseconds]}},
      ...>   []
      ...> )
      %Drops.Types.Cast{
        input_type: %Drops.Types.Type{
          primitive: :integer,
          constraints: [predicate: {:type?, :integer}]
        },
        output_type: %Drops.Types.Type{
          primitive: :date_time,
          constraints: [predicate: {:type?, :date_time}]
        },
        opts: [:miliseconds]
      }

  """
  defstruct [:input_type, :output_type, :opts]
end
