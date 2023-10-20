defmodule Drops.Contract.Types.MapTest do
  use Drops.ContractCase

  describe "map/0" do
    contract do
      schema do
        %{required(:test) => map()}
      end
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: %{}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert_errors(["test must be a map"], contract.conform(%{test: 312}))
    end
  end

  describe "map/1 with extra predicates" do
    contract do
      schema do
        %{required(:test) => map(:filled?)}
      end
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: %{hello: "World"}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert_errors(["test must be a map"], contract.conform(%{test: 312}))
    end
  end
end
