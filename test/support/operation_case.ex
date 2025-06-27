defmodule Drops.OperationCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Drops.DataCase
      import Drops.OperationCase
    end
  end

  defmacro operation(opts \\ [], do: body) do
    {name, operation_opts} =
      case opts do
        atom when is_atom(atom) ->
          # Old syntax: operation :command do ... end
          {:operation, [type: atom]}

        keyword_list when is_list(keyword_list) ->
          Keyword.pop(keyword_list, :name, :operation)
      end

    test_id = System.unique_integer([:positive])
    app_module_name = Module.concat(__CALLER__.module, :"TestApp#{test_id}")
    operation_module_name = Module.concat(__CALLER__.module, :"TestOperation#{test_id}")

    quote do
      setup(context) do
        defmodule unquote(app_module_name) do
          use Drops.Operations, repo: Drops.TestRepo
        end

        defmodule unquote(operation_module_name) do
          use unquote(app_module_name), unquote(operation_opts)

          unquote(body)
        end

        on_exit(fn ->
          :code.purge(unquote(app_module_name))
          :code.delete(unquote(app_module_name))
          :code.purge(unquote(operation_module_name))
          :code.delete(unquote(operation_module_name))
        end)

        operation_context =
          Map.put(context, unquote(name), unquote(operation_module_name))

        {:ok, operation_context}
      end
    end
  end
end
