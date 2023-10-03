defmodule Drops.Type.Schema do
  alias __MODULE__
  alias Drops.Type
  alias Schema.Key

  import Type, only: [infer_constraints: 2]

  defstruct [:primitive, :constraints, :keys, :atomize]

  def new(spec, opts) do
    atomize = opts[:atomize] || false
    keys = to_key_list(spec, opts)

    %Schema{
      primitive: :map,
      constraints: infer_constraints({:type, {:map, []}}, opts),
      atomize: atomize,
      keys: keys
    }
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

  defp to_key_list(spec, opts, root \\ []) do
    Enum.map(spec, fn {{presence, name}, spec} ->
      Key.new(spec, opts, presence: presence, path: root ++ [name])
    end)
  end
end
