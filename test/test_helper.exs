defmodule Drops.ContractCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Drops.ContractCase

      alias Drops.Contract.Map
    end
  end

  defmacro contract(do: body) do
    quote do
      setup(_) do
        defmodule TestContract do
          use Drops.Contract

          unquote(body)
        end

        on_exit(fn ->
          :code.purge(__MODULE__.TestContract)
          :code.delete(__MODULE__.TestContract)
        end)

        {:ok, contract: TestContract}
      end
    end
  end
end

ExUnit.start()
