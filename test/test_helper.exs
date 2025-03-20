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

        {:ok, contract: TestContract}
      end
    end
  end
end

Code.put_compiler_option(:ignore_module_conflict, true)
ExUnit.start()
