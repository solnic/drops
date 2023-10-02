defmodule Drops.Contract.Schema do
  alias __MODULE__
  alias Drops.Contract.Key
  alias Drops.Contract.Type

  import Type, only: [infer_constraints: 2]

  defstruct [:primitive, :constraints, :keys, :plan, :atomize]

  def new(spec, opts) do
    atomize = opts[:atomize] || false
    keys = to_key_list(spec, opts)

    %Schema{
      primitive: :map,
      constraints: infer_constraints({:type, {:map, []}}, opts),
      atomize: atomize,
      keys: keys,
      plan: build_plan(keys)
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

  defp build_plan(keys) do
    Enum.map(keys, &key_step/1)
  end

  defp key_step(%{children: children} = key) when length(children) > 0 do
    {:and, [{:validate, key}, build_plan(children)]}
  end

  defp key_step(key) do
    {:validate, key}
  end
end
