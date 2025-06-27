defmodule Drops.DoctestCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      setup do
        modules_before = :code.all_loaded() |> Enum.map(&elem(&1, 0)) |> MapSet.new()

        on_exit(fn ->
          modules_after = :code.all_loaded() |> Enum.map(&elem(&1, 0)) |> MapSet.new()
          new_modules = MapSet.difference(modules_after, modules_before)
          test_module_prefix = to_string(__MODULE__)

          Enum.each(new_modules, fn module ->
            module_string = to_string(module)

            if String.starts_with?(module_string, test_module_prefix) do
              try do
                :code.purge(module)
                :code.delete(module)
              rescue
                _ -> :ok
              end
            end
          end)
        end)

        :ok
      end
    end
  end
end
