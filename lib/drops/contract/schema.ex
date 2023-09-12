defmodule Drops.Contract.Schema do
  alias __MODULE__

  defstruct [:keys, :plan]

  defmodule Key do
    defstruct [:path, :presence, :predicates, children: []]

    def present?(map, _) when not is_map(map) do
      true
    end

    def present?(_map, []) do
      true
    end

    def present?(map, %Key{} = key) do
      present?(map, key.path)
    end

    def present?(map, [key | tail]) do
      Map.has_key?(map, key) and present?(map[key], tail)
    end
  end

  def new(map, opts) do
    keys = to_key_list(map)

    %Schema{keys: keys, plan: build_plan(keys)}
  end

  defp to_key_list(map, root \\ []) do
    Enum.map(map, fn {{presence, name}, value} ->
      case value do
        %{} ->
          build_key(
            presence,
            root ++ [name],
            [{:predicate, {:type?, :map}}],
            to_key_list(value, root ++ [name])
          )

        _ ->
          build_key(presence, root ++ [name], value)
      end
    end)
  end

  defp build_key(presence, path, predicates, children \\ []) do
    %Key{path: path, presence: presence, predicates: predicates, children: children}
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
