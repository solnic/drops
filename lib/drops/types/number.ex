defmodule Drops.Types.Number do
  @moduledoc ~S"""
  Drops.Types.Number is a struct that represents a number type
  that can be either an integer or a float

  ## Examples

      iex> defmodule ProductContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       name: string(:filled?),
      ...>       price: number()
      ...>     }
      ...>   end
      ...> end
      iex> ProductContract.conform(%{name: "Book", price: 31.2})
      {:ok, %{name: "Book", price: 31.2}}
      iex> ProductContract.conform(%{name: "Book", price: 31})
      {:ok, %{name: "Book", price: 31}}
      iex> {:error, errors} = ProductContract.conform(%{name: "Book", price: []})
      {:error,
       [
         %Drops.Validator.Messages.Error.Type{
           path: [:price],
           text: "must be a number",
           meta: []
         }
       ]}
      iex> Enum.map(errors, &to_string/1)
      ["price must be a number"]
  """
  @doc since: "0.2.0"

  use(Drops.Type, union([:integer, :float]))

  @opts name: :number
end
