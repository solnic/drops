defmodule Drops.ContractCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Drops.Contract.Messages.DefaultBackend, as: MessageBackend

      import Drops.ContractCase

      def assert_errors(errors, {:error, results}) do
        assert errors == MessageBackend.errors(results) |> Enum.map(&to_string/1)
      end
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
