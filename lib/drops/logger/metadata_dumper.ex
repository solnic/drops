defprotocol Drops.Logger.MetadataDumper do
  @moduledoc """
  Protocol for dumping metadata values into logs.

  This protocol provides a way to customize how different types of values
  are formatted when included in log metadata. It's particularly useful for
  complex data structures that need special formatting for readability.

  ## Default Implementations

  The protocol provides implementations for common Elixir types:

  - Basic types (strings, numbers, atoms) are formatted as-is
  - Lists are formatted with a maximum of 4 items, showing count for larger lists
  - Maps are formatted with a maximum of 3 key-value pairs, showing count for larger maps
  - Structs like `Ecto.Changeset` have special formatting

  ## Custom Implementations

  You can implement this protocol for your own types:

      defimpl Drops.Logger.MetadataDumper, for: MyStruct do
        def dump(%MyStruct{name: name, status: status}) do
          "MyStruct(name: \#{name}, status: \#{status})"
        end
      end

  ## Examples

      iex> alias Drops.Logger.MetadataDumper
      iex> MetadataDumper.dump("hello")
      "\\"hello\\""

      iex> MetadataDumper.dump([1, 2, 3])
      "[1, 2, 3]"

      iex> MetadataDumper.dump([1, 2, 3, 4, 5])
      "[5 items]"

      iex> MetadataDumper.dump(%{a: 1, b: 2})
      "%{:a => 1, :b => 2}"
  """

  @fallback_to_any true

  @doc """
  Dumps a value into a string representation suitable for logging.

  Returns a string that represents the value in a concise, readable format
  appropriate for log output.
  """
  @spec dump(term()) :: String.t()
  def dump(value)
end

defimpl Drops.Logger.MetadataDumper, for: BitString do
  def dump(string) when is_binary(string) do
    inspect(string)
  end
end

defimpl Drops.Logger.MetadataDumper, for: Atom do
  def dump(atom) do
    inspect(atom)
  end
end

defimpl Drops.Logger.MetadataDumper, for: Integer do
  def dump(integer) do
    to_string(integer)
  end
end

defimpl Drops.Logger.MetadataDumper, for: Float do
  def dump(float) do
    to_string(float)
  end
end

defimpl Drops.Logger.MetadataDumper, for: List do
  alias Drops.Logger.MetadataDumper

  def dump(list) when length(list) <= 4 do
    items = Enum.map(list, &MetadataDumper.dump/1)
    "[#{Enum.join(items, ", ")}]"
  end

  def dump(list) do
    "[#{length(list)} items]"
  end
end

defimpl Drops.Logger.MetadataDumper, for: Map do
  alias Drops.Logger.MetadataDumper

  def dump(map) when map_size(map) <= 3 do
    pairs =
      map
      |> Enum.sort_by(fn {key, _value} -> key end)
      |> Enum.map(fn {key, value} ->
        "#{MetadataDumper.dump(key)} => #{MetadataDumper.dump(value)}"
      end)

    "%{#{Enum.join(pairs, ", ")}}"
  end

  def dump(map) do
    "%{#{map_size(map)} keys}"
  end
end

defimpl Drops.Logger.MetadataDumper, for: Any do
  def dump(value) do
    inspect(value)
  end
end

if Code.ensure_loaded?(Ecto.Changeset) do
  defimpl Drops.Logger.MetadataDumper, for: Ecto.Changeset do
    def dump(%Ecto.Changeset{valid?: valid?, changes: changes, errors: errors}) do
      status = if valid?, do: "valid", else: "invalid"
      changes_count = map_size(changes)
      errors_count = length(errors)

      case {changes_count, errors_count} do
        {0, 0} -> "Ecto.Changeset(#{status})"
        {c, 0} -> "Ecto.Changeset(#{status}), #{c} changes"
        {0, e} -> "Ecto.Changeset(#{status}), #{e} errors"
        {c, e} -> "Ecto.Changeset(#{status}), #{c} changes, #{e} errors"
      end
    end
  end
end
