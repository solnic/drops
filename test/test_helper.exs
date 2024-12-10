defmodule Drops.ContractCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      alias Drops.Validator.Messages.DefaultBackend, as: MessageBackend

      import Drops.ContractCase

      def assert_errors(errors, {:error, messages}) do
        assert errors ==
                 messages
                 |> Enum.map(&to_string/1)
                 |> Enum.sort()
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
