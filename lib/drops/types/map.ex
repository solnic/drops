defmodule Drops.Types.Map do
  alias Drops.Types.Map.Key

  defstruct [:primitive, :constraints, :keys, :atomize]

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
