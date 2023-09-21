defmodule Drops.MaybeTest do
  use Drops.ContractCase

  describe "maybe/1 with :string" do
    contract do
      schema do
        %{required(:test) => maybe(:string)}
      end
    end

    test "returns success with nil", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: nil})
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "hello"})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:string, 312]}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "maybe/1 with :string and extra predicates" do
    contract do
      schema do
        %{required(:test) => maybe(:string, [:filled?])}
      end
    end

    test "returns success with nil", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: nil})
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "hello"})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:string, 312]}}]} =
               contract.conform(%{test: 312})
    end

    test "returns error when extra predicates fail", %{contract: contract} do
      assert {:error, [{:error, {[:test], :filled?, [""]}}]} =
               contract.conform(%{test: ""})
    end
  end
end
