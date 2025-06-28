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
        end)

        {:ok, contract: TestContract}
      end
    end
  end
end

Code.require_file("support/test_config.ex", __DIR__)
Code.require_file("support/doctest_case.ex", __DIR__)
Code.require_file("support/data_case.ex", __DIR__)
Code.require_file("support/operation_case.ex", __DIR__)
Code.require_file("support/ecto/test_schemas.ex", __DIR__)
Code.require_file("support/ecto/user_group_schemas.ex", __DIR__)

Application.ensure_all_started(:drops)

ExUnit.start()
