defmodule Drops.Predicates do
  @moduledoc ~S"""
  Drops.Predicates is a module that provides validation functions that can be used as the
  type constraints.
  """
  require Integer

  @doc ~S"""
  Checks if a given value matches a given type identifier

  ## Examples

      iex> Drops.Predicates.type?(:nil, nil)
      true
      iex> Drops.Predicates.type?(:any, nil)
      true
      iex> Drops.Predicates.type?(:any, "foo")
      true
      iex> Drops.Predicates.type?(:atom, :hello)
      true
      iex> Drops.Predicates.type?(:boolean, true)
      true
      iex> Drops.Predicates.type?(:boolean, false)
      true
      iex> Drops.Predicates.type?(:string, "hello")
      true
      iex> Drops.Predicates.type?(:integer, 1)
      true
      iex> Drops.Predicates.type?(:float, 1.2)
      true
      iex> Drops.Predicates.type?(:map, %{})
      true
      iex> Drops.Predicates.type?(:date_time, DateTime.utc_now())
      true

  """
  @spec type?(type :: atom, input :: any) :: boolean()

  def type?(nil, nil), do: true
  def type?(nil, _), do: false

  def type?(:any, _), do: true

  def type?(:atom, input) when is_atom(input), do: true
  def type?(:atom, _), do: false

  def type?(:boolean, input) when is_boolean(input), do: true
  def type?(:boolean, _), do: false

  def type?(:string, input) when is_binary(input), do: true
  def type?(:string, _), do: false

  def type?(:integer, input) when is_integer(input), do: true
  def type?(:integer, _), do: false

  def type?(:float, input) when is_float(input), do: true
  def type?(:float, _), do: false

  def type?(:map, input) when is_map(input), do: true
  def type?(:map, _), do: false

  def type?(:list, input) when is_list(input), do: true
  def type?(:list, _), do: false

  def type?(:date, %Date{}), do: true
  def type?(:date, _), do: false

  def type?(:date_time, %DateTime{}), do: true
  def type?(:date_time, _), do: false

  def type?(:time, %Time{}), do: true
  def type?(:time, _), do: false

  @doc ~S"""
  Checks if a given input is not empty


  ## Examples

      iex> Drops.Predicates.filled?("hello")
      true
      iex> Drops.Predicates.filled?("")
      false
      iex> Drops.Predicates.filled?(["hello", "world"])
      true
      iex> Drops.Predicates.filled?(%{hello: "world"})
      true
      iex> Drops.Predicates.filled?(%{})
      false

  """
  @spec filled?(input :: binary() | list() | map()) :: boolean()
  def filled?(input) do
    not empty?(input)
  end

  @doc ~S"""
  Checks if a given input is empty


  ## Examples

      iex> Drops.Predicates.empty?("hello")
      false
      iex> Drops.Predicates.empty?("")
      true
      iex> Drops.Predicates.empty?(["hello", "world"])
      false
      iex> Drops.Predicates.empty?(%{hello: "world"})
      false
      iex> Drops.Predicates.empty?(%{})
      true

  """
  @spec empty?(input :: binary() | list() | map()) :: boolean()
  def empty?(""), do: true
  def empty?([]), do: true
  def empty?(%{} = input) when map_size(input) == 0, do: true
  def empty?(_), do: false

  @doc ~S"""
  Checks if a given value is equal to another value

  ## Examples

      iex> Drops.Predicates.eql?("hello", "hello")
      true
      iex> Drops.Predicates.eql?("hello", "world")
      false

  """
  @spec eql?(value :: any(), input :: any()) :: boolean()
  def eql?(value, input) when value == input, do: true
  def eql?(_, _), do: false

  @doc ~S"""
  Checks if a given value is not equal to another value

  ## Examples

      iex> Drops.Predicates.not_eql?("hello", "hello")
      false
      iex> Drops.Predicates.not_eql?("hello", "world")
      true

  """
  @spec not_eql?(value :: any(), input :: any()) :: boolean()
  def not_eql?(value, input), do: not eql?(value, input)

  @doc ~S"""
  Checks if a given integer is even

  ## Examples

      iex> Drops.Predicates.even?(4)
      true
      iex> Drops.Predicates.even?(7)
      false

  """
  @spec even?(input :: integer()) :: boolean()
  def even?(input), do: Integer.is_even(input)

  @doc ~S"""
  Checks if a given integer is odd

  ## Examples

      iex> Drops.Predicates.odd?(4)
      false
      iex> Drops.Predicates.odd?(7)
      true

  """
  @spec odd?(input :: integer()) :: boolean()
  def odd?(input), do: not even?(input)

  @doc ~S"""
  Checks if a given input is greater than another value

  ## Examples

      iex> Drops.Predicates.gt?(2, 1)
      false
      iex> Drops.Predicates.gt?(1, 2)
      true

  """
  @spec gt?(value :: any(), input :: any()) :: boolean()
  def gt?(value, input) when value < input, do: true
  def gt?(value, input) when value >= input, do: false

  @doc ~S"""
  Checks if a given value is greater than or equal to another value

  ## Examples

      iex> Drops.Predicates.gteq?(2, 1)
      false
      iex> Drops.Predicates.gteq?(1, 1)
      true
      iex> Drops.Predicates.gteq?(1, 2)
      true

  """
  @spec gteq?(value :: any(), input :: any()) :: boolean()
  def gteq?(value, input) when value <= input, do: true
  def gteq?(value, input) when value > input, do: false

  @doc ~S"""
  Checks if a given input is less than another value

  ## Examples

      iex> Drops.Predicates.lt?(2, 1)
      true
      iex> Drops.Predicates.lt?(1, 2)
      false

  """
  @spec lt?(value :: any(), input :: any()) :: boolean()
  def lt?(value, input) when value > input, do: true
  def lt?(value, input) when value <= input, do: false

  @doc ~S"""
  Checks if a given input is less than or equal to another value

  ## Examples

      iex> Drops.Predicates.lteq?(2, 1)
      true
      iex> Drops.Predicates.lteq?(1, 1)
      true
      iex> Drops.Predicates.lteq?(1, 2)
      false
  """
  @spec lteq?(value :: any(), input :: any()) :: boolean()
  def lteq?(value, input) when value >= input, do: true
  def lteq?(value, input) when value < input, do: false

  @doc ~S"""
  Checks if a given list, map or string size is equal to a given size

  ## Examples

      iex> Drops.Predicates.size?(2, "ab")
      true
      iex> Drops.Predicates.size?(2, "abc")
      false
      iex> Drops.Predicates.size?(2, [1, 2])
      true
      iex> Drops.Predicates.size?(2, [1, 2, 3])
      false
      iex> Drops.Predicates.size?(2, %{a: 1, b: 2})
      true
      iex> Drops.Predicates.size?(2, %{a: 1, b: 2, c: 3})
      false

  """
  @spec size?(size :: integer(), input :: map() | list() | String.t()) :: boolean()
  def size?(size, input) when is_map(input) and map_size(input) == size, do: true
  def size?(size, input) when is_map(input) and map_size(input) != size, do: false
  def size?(size, input) when is_list(input) and length(input) == size, do: true
  def size?(size, input) when is_list(input) and length(input) != size, do: false
  def size?(size, input) when is_binary(input), do: String.length(input) == size

  @doc ~S"""
  Checks if a given string matches a given regular expression

  ## Examples

      iex> Drops.Predicates.match?(~r/hello/, "hello world")
      true
      iex> Drops.Predicates.match?(~r/hello/, "world")
      false

  """
  @spec match?(regexp :: Regex.t(), input :: binary()) :: boolean()
  def match?(regexp, input), do: String.match?(input, regexp)

  @doc ~S"""
  Checks if a given map, list or string size is less than or equal to a given size

  ## Examples

      iex> Drops.Predicates.max_size?(2, "a")
      true
      iex> Drops.Predicates.max_size?(2, "ab")
      true
      iex> Drops.Predicates.max_size?(2, "abc")
      false
      iex> Drops.Predicates.max_size?(2, [1, 2])
      true
      iex> Drops.Predicates.max_size?(2, [1, 2, 3])
      false
      iex> Drops.Predicates.max_size?(2, %{a: 1, b: 2})
      true
      iex> Drops.Predicates.max_size?(2, %{a: 1, b: 2, c: 3})
      false

  """
  @spec max_size?(size :: integer(), input :: map() | list() | String.t()) :: boolean()
  def max_size?(size, input) when is_map(input) and map_size(input) <= size, do: true
  def max_size?(size, input) when is_map(input) and map_size(input) > size, do: false
  def max_size?(size, input) when is_list(input) and length(input) <= size, do: true
  def max_size?(size, input) when is_list(input) and length(input) > size, do: false
  def max_size?(size, input) when is_binary(input), do: String.length(input) <= size

  @doc ~S"""
  Checks if a given map, list or string size is greater than or equal to a given size

  ## Examples

      iex> Drops.Predicates.min_size?(2, "ab")
      true
      iex> Drops.Predicates.min_size?(2, "abc")
      true
      iex> Drops.Predicates.min_size?(2, "a")
      false
      iex> Drops.Predicates.min_size?(2, [1, 2])
      true
      iex> Drops.Predicates.min_size?(2, [1])
      false
      iex> Drops.Predicates.min_size?(2, %{a: 1, b: 2})
      true
      iex> Drops.Predicates.min_size?(2, %{a: 1})
      false

  """
  @spec min_size?(size :: integer(), input :: map() | list() | String.t()) :: boolean()
  def min_size?(size, input) when is_map(input) and map_size(input) >= size, do: true
  def min_size?(size, input) when is_map(input) and map_size(input) < size, do: false
  def min_size?(size, input) when is_list(input) and length(input) >= size, do: true
  def min_size?(size, input) when is_list(input) and length(input) < size, do: false
  def min_size?(size, input) when is_binary(input), do: String.length(input) >= size

  @doc ~S"""
  Checks if a given element is included in a given list

  ## Examples

      iex> Drops.Predicates.includes?(1, [1, 2, 3])
      true
      iex> Drops.Predicates.includes?(4, [1, 2, 3])
      false

  """
  @spec includes?(element :: any(), input :: list()) :: boolean()
  def includes?(element, input) when is_list(input), do: element in input

  @doc ~S"""
  Checks if a given element is not included in a given list

  ## Examples

      iex> Drops.Predicates.excludes?(1, [1, 2, 3])
      false
      iex> Drops.Predicates.excludes?(4, [1, 2, 3])
      true

  """
  @spec excludes?(element :: any(), input :: list()) :: boolean()
  def excludes?(element, input) when is_list(input), do: not includes?(element, input)

  @doc ~S"""
  Checks if a given element is included in a given list

  ## Examples

      iex> Drops.Predicates.in?([1, 2, 3], 2)
      true
      iex> Drops.Predicates.in?([1, 2, 3], 4)
      false

  """
  @spec in?(list :: list(), input :: any()) :: boolean()
  def in?(list, input) when is_list(list), do: input in list

  @doc ~S"""
  Checks if a given element is not included in a given list

  ## Examples

      iex> Drops.Predicates.not_in?([1, 2, 3], 2)
      false
      iex> Drops.Predicates.not_in?([1, 2, 3], 4)
      true

  """
  @spec not_in?(list :: list(), input :: any()) :: boolean()
  def not_in?(list, input) when is_list(list), do: input not in list
end
