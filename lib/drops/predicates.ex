defmodule Drops.Predicates do
  require Integer

  def type?(:nil, nil), do: true
  def type?(:nil, _), do: false

  def type?(:atom, value) when is_atom(value), do: true
  def type?(:atom, _), do: false

  def type?(:string, value) when is_binary(value), do: true
  def type?(:string, _), do: false

  def type?(:integer, value) when is_integer(value), do: true
  def type?(:integer, _), do: false

  def type?(:float, value) when is_float(value), do: true
  def type?(:float, _), do: false

  def type?(:map, value) when is_map(value), do: true
  def type?(:map, _), do: false

  def type?(:list, value) when is_list(value), do: true
  def type?(:list, _), do: false

  def type?(:date, %Date{}), do: true
  def type?(:date, _), do: false

  def type?(:date_time, %DateTime{}), do: true
  def type?(:date_time, _), do: false

  def type?(:time, %Time{}), do: true
  def type?(:time, _), do: false

  def filled?(value) do
    not empty?(value)
  end

  def empty?(""), do: true
  def empty?([]), do: true
  def empty?(%{} = value) when map_size(value) == 0, do: true

  def empty?(_), do: false

  def eql?(left, right) when left == right, do: true
  def eql?(_, _), do: false

  def not_eql?(left, right), do: not eql?(left, right)

  def even?(value), do: Integer.is_even(value)

  def odd?(value), do: not even?(value)

  def gt?(left, right) when left < right, do: true
  def gt?(left, right) when left >= right, do: false

  def gteq?(left, right) when left <= right, do: true
  def gteq?(left, right) when left > right, do: false

  def lt?(left, right) when left > right, do: true
  def lt?(left, right) when left <= right, do: false

  def lteq?(left, right) when left >= right, do: true
  def lteq?(left, right) when left < right, do: false

  def size?(size, value) when is_map(value) and map_size(value) == size, do: true
  def size?(size, value) when is_map(value) and map_size(value) != size, do: false
  def size?(size, value) when is_list(value) and length(value) == size, do: true
  def size?(size, value) when is_list(value) and length(value) != size, do: false

  def match?(regexp, value), do: String.match?(value, regexp)

  def max_size?(size, value) when is_map(value) and map_size(value) <= size, do: true
  def max_size?(size, value) when is_map(value) and map_size(value) > size, do: false

  def max_size?(size, value) when is_list(value) and length(value) <= size, do: true
  def max_size?(size, value) when is_list(value) and length(value) > size, do: false

  def min_size?(size, value) when is_map(value) and map_size(value) >= size, do: true
  def min_size?(size, value) when is_map(value) and map_size(value) < size, do: false

  def min_size?(size, value) when is_list(value) and length(value) >= size, do: true
  def min_size?(size, value) when is_list(value) and length(value) < size, do: false

  def includes?(element, value) when is_list(value), do: element in value

  def excludes?(element, value) when is_list(value), do: not includes?(element, value)
end
