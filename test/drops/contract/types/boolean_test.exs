defmodule Drops.Contract.Types.BooleanTest do
  use Drops.ContractCase

  describe "boolean/0" do
    contract do
      schema do
        %{required(:test) => boolean()}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: true}} = contract.conform(%{test: true})
      assert {:ok, %{test: false}} = contract.conform(%{test: false})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(["test must be boolean"], contract.conform(%{test: :invalid}))
    end
  end
end
