defmodule Drops.Predicates do
  require Integer

  def type?(:atom, value) when is_atom(value), do: {:ok, value}
  def type?(:atom, value), do: {:error, {:atom?, value}}

  def type?(:string, value) when is_binary(value), do: {:ok, value}
  def type?(:string, value), do: {:error, {:string?, value}}

  def type?(:integer, value) when is_integer(value), do: {:ok, value}
  def type?(:integer, value), do: {:error, {:integer?, value}}

  def type?(:float, value) when is_float(value), do: {:ok, value}
  def type?(:float, value), do: {:error, {:float?, value}}

  def type?(:map, value) when is_map(value), do: {:ok, value}
  def type?(:map, value), do: {:error, {:map?, value}}

  def type?(:list, value) when is_list(value), do: {:ok, value}
  def type?(:list, value), do: {:error, {:list?, value}}

  def type?(:date, %Date{} = value), do: {:ok, value}
  def type?(:date, value), do: {:error, {:date?, value}}

  def type?(:date_time, %DateTime{} = value), do: {:ok, value}
  def type?(:date_time, value), do: {:error, {:date_time?, value}}

  def type?(:time, %Time{} = value), do: {:ok, value}
  def type?(:time, value), do: {:error, {:time?, value}}

  def filled?(value) do
    case empty?(value) do
      {:ok, _} -> {:error, {:filled?, value}}
      {:error, _} -> {:ok, value}
    end
  end

  def empty?("" = value), do: {:ok, value}
  def empty?([] = value), do: {:ok, value}
  def empty?(%{} = value) when map_size(value) == 0, do: {:ok, value}

  def empty?(value), do: {:error, {:empty?, value}}

  def eql?(left, right) when left == right, do: {:ok, right}

  def eql?(left, right), do: {:error, {:eql?, [left, right]}}

  def not_eql?(left, right) do
    case eql?(left, right) do
      {:ok, _} -> {:error, {:not_eql?, [left, right]}}
      {:error, _} -> {:ok, right}
    end
  end

  def even?(value) do
    case Integer.is_even(value) do
      true -> {:ok, value}
      false -> {:error, {:even?, value}}
    end
  end

  def odd?(value) do
    case Integer.is_odd(value) do
      true -> {:ok, value}
      false -> {:error, {:odd?, value}}
    end
  end

  def gt?(left, right) when left < right, do: {:ok, right}
  def gt?(left, right) when left >= right, do: {:error, {:gt?, [left, right]}}

  def gteq?(left, right) when left <= right, do: {:ok, right}
  def gteq?(left, right) when left > right, do: {:error, {:gteq?, [left, right]}}

  def lt?(left, right) when left > right, do: {:ok, right}
  def lt?(left, right) when left <= right, do: {:error, {:lt?, [left, right]}}

  def lteq?(left, right) when left >= right, do: {:ok, right}
  def lteq?(left, right) when left < right, do: {:error, {:lteq?, [left, right]}}

  def size?(size, value) when is_map(value) and map_size(value) == size, do: {:ok, value}

  def size?(size, value) when is_map(value) and map_size(value) != size,
    do: {:error, {:size?, [size, value]}}

  def size?(size, value) when is_list(value) and length(value) == size, do: {:ok, value}

  def size?(size, value) when is_list(value) and length(value) != size,
    do: {:error, {:size?, [size, value]}}
end
