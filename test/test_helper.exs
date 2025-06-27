defmodule Drops.ContractCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Drops.Validator.Messages.DefaultBackend, as: MessageBackend

      import Drops.ContractCase

      def assert_errors(errors, {:error, messages}) do
        assert errors == Enum.map(messages, &to_string/1)
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
        end)

        {:ok, contract: TestContract}
      end
    end
  end
end

Code.require_file("support/doctest_case.ex", __DIR__)

ExUnit.start()
