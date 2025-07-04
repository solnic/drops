defmodule Drops.OperationCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Drops.DataCase
      use Drops.DoctestCase
      import Drops.OperationCase
      import Drops.Test.Config
    end
  end

  defmacro operation(opts \\ [], do: body) do
    {name, operation_opts} =
      case opts do
        atom when is_atom(atom) ->
          {:operation, [type: atom]}

        keyword_list when is_list(keyword_list) ->
          Keyword.pop(keyword_list, :name, :operation)
      end

    test_id =
      "#{System.unique_integer([:positive])}_#{:erlang.phash2(self())}_#{:erlang.phash2(__CALLER__.line)}"

    app_module_name = Module.concat(__CALLER__.module, :"TestApp#{test_id}")
    operation_module_name = Module.concat(__CALLER__.module, :"TestOperation#{test_id}")

    quote do
      setup(context) do
        # Include repo if test has ecto_schemas tag or explicitly requested
        needs_repo =
          Map.has_key?(context, :ecto_schemas) or
            Keyword.has_key?(unquote(operation_opts), :repo)

        if needs_repo do
          defmodule unquote(app_module_name) do
            use Drops.Operations, repo: Drops.TestRepo
          end
        else
          defmodule unquote(app_module_name) do
            use Drops.Operations
          end
        end

        defmodule unquote(operation_module_name) do
          use unquote(app_module_name), unquote(operation_opts)

          unquote(body)
        end

        on_exit(fn ->
          try do
            :code.purge(unquote(operation_module_name))
            :code.delete(unquote(operation_module_name))
          rescue
            _ -> :ok
          end

          try do
            :code.purge(unquote(app_module_name))
            :code.delete(unquote(app_module_name))
          rescue
            _ -> :ok
          end

          :erlang.garbage_collect()
        end)

        operation_context =
          Map.put(context, unquote(name), unquote(operation_module_name))

        {:ok, operation_context}
      end
    end
  end
end
