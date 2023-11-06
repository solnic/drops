defmodule Drops.Casters do
  @moduledoc ~S"""
  Drops.Casters is a module that provides functions for casting values
  from one type to another.

  This module is the default caster module used by the Drops.Type.DSL.cast function.
  """

  @doc ~S"""
  Casts a string into an integer

  ## Casting a string into an integer

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{required(:age) => cast(:string) |> type(:integer)}
      ...>   end
      ...> end
      iex> UserContract.conform(%{age: "20"})
      {:ok, %{age: 20}}

  ## Casting a string into a float

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{required(:num) => cast(:string) |> type(:float)}
      ...>   end
      ...> end
      iex> UserContract.conform(%{num: "20.5"})
      {:ok, %{num: 20.5}}

  ## Casting an integer into a string

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{required(:id) => cast(:integer) |> type(:string)}
      ...>   end
      ...> end
      iex> UserContract.conform(%{id: 312})
      {:ok, %{id: "312"}}

  ## Casting an integer into a date time

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{required(:date) => cast(:integer) |> type(:date_time)}
      ...>   end
      ...> end
      iex> UserContract.conform(%{date: 1614556800})
      {:ok, %{date: ~U[2021-03-01 00:00:00Z]}}

  """
  @spec cast(:string, :integer, value :: String.t()) :: integer()
  @spec cast(:string, :float, value :: String.t()) :: float()
  @spec cast(:integer, :string, value :: integer()) :: String.t()
  @spec cast(:integer, :date_time, value :: integer(), unit :: atom()) :: DateTime.t()

  def cast(:string, :integer, value), do: String.to_integer(value)

  def cast(:string, :float, value) do
    {float, _} = Float.parse(value)
    float
  end

  def cast(:integer, :string, value), do: to_string(value)

  def cast(:integer, :date_time, value, unit \\ :second),
    do: DateTime.from_unix!(value, unit)
end
