defmodule Drops.Types.Map do
  @moduledoc ~S"""
  Drops.Types.Map is a struct that represents a map type with optional constraints.

  ## Examples

      iex> Drops.Types.from_spec({:type, {:map, []}}, [])
      %Drops.Types.Primitive{primitive: :map, constraints: [predicate: {:type?, :map}]}

      iex> Drops.Types.from_spec(%{
      ...>   {:required, :name} => {:type, {:string, []}},
      ...>   {:optional, :age} => {:type, {:integer, []}}
      ...> }, [])
      %Drops.Types.Map{
        primitive: :map,
        constraints: [predicate: {:type?, :map}],
        keys: [
          %Drops.Types.Map.Key{
            path: [:age],
            presence: :optional,
            type: %Drops.Types.Primitive{
              primitive: :integer,
              constraints: [predicate: {:type?, :integer}]
            }
          },
          %Drops.Types.Map.Key{
            path: [:name],
            presence: :required,
            type: %Drops.Types.Primitive{
              primitive: :string,
              constraints: [predicate: {:type?, :string}]
            }
          }
        ],
        atomize: false
      }

  """

  alias Drops.Types.Map.Key

  use Drops.Type do
    deftype :map, [keys: [], atomize: false]

    def new(keys, opts) when is_list(keys) do
      atomize = opts[:atomize] || false
      struct(__MODULE__, keys: keys, atomize: atomize)
    end
  end

  def atomize(data, keys, initial \\ %{}) do
    Enum.reduce(keys, initial, fn %{path: path} = key, acc ->
      stringified_key = Key.stringify(key)

      if Key.present?(data, stringified_key) do
        put_in(acc, path, get_in(data, stringified_key.path))
      else
        acc
      end
    end)
  end
end
