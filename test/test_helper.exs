defmodule Drops.ContractCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      import Drops.ContractCase
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

          # Defined in doctests
          :code.purge(__MODULE__.UserContract)
          :code.delete(__MODULE__.UserContract)
        end)

        {:ok, contract: TestContract}
      end
    end
  end
end

ExUnit.start()
