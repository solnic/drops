defmodule Drops.CoercionTest do
  use ExUnit.Case

  describe "schema" do
    setup(_) do
      on_exit(fn ->
        :code.purge(Drops.CoercionTest.TestContract)
        :code.delete(Drops.CoercionTest.TestContract)
      end)
    end

    test "defining a required key with coercion" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          %{
            required(:code) => from(:integer) |> type(:string),
            required(:price) => from(:string) |> type(:integer)
          }
        end
      end

      assert {:ok, %{code: "12", price: 11}} =
               TestContract.conform(%{code: 12, price: "11"})
    end
  end
end
