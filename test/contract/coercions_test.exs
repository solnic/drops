defmodule Drops.CoercionTest do
  use Drops.ContractCase

  describe "coercions" do
    contract do
      schema do
        %{
          required(:code) => from(:integer) |> type(:string),
          required(:price) => from(:string) |> type(:integer)
        }
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{code: "12", price: 11}} = contract.conform(%{code: 12, price: "11"})
    end
  end
end
