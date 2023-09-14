defmodule Drops.Contract.Schema do
  alias __MODULE__
  alias Drops.Contract.Schema.Key

  defstruct [:keys, :plan, :atomize]

  def new(map, opts) do
    atomize = opts[:atomize] || false
    keys = to_key_list(map)

    %Schema{atomize: atomize, keys: keys, plan: build_plan(keys)}
  end

  def atomize(data, keys, initial \\ %{}) do
    Enum.reduce(keys, initial, fn %{path: path} = key, acc ->
      string_path = Enum.map(path, &Atom.to_string/1)
      value = get_in(data, string_path)

      unless is_nil(value) do
        updated = put_in(acc, path, value)
        with_children = atomize(data, key.children, updated)
        atom_part = List.delete(path, List.last(path))
        string_part = List.last(string_path)

        mixed_path = atom_part ++ [string_part]

        {_, result} = pop_in(with_children, mixed_path)

        result
      else
        acc
      end
    end)
  end

  defp to_key_list(map, root \\ []) do
    Enum.map(map, fn {{presence, name}, spec} ->
      path = root ++ [name]

      case spec do
        %{} ->
          Key.new({:type, {:map, []}},
            presence: presence,
            path: path,
            children: to_key_list(spec, path)
          )

        _ ->
          Key.new(spec, presence: presence, path: path)
      end
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
