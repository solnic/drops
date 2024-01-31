defmodule Drops.Contract.Types.AnyTest do
  use Drops.ContractCase

  describe "boolean/0" do
    contract do
      schema do
        %{required(:test) => any()}
      end
    end

    test "returns success with any input", %{contract: contract} do
      assert {:ok, %{test: true}} = contract.conform(%{test: true})
      assert {:ok, %{test: "foo"}} = contract.conform(%{test: "foo"})
    end
  end
end
