defmodule Drops.Contract.Types.StringTest do
  use Drops.ContractCase

  describe "string/0" do
    contract do
      schema do
        %{required(:test) => string()}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "Hello"})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:string, 312]}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "string/1 with extra predicates" do
    contract do
      schema do
        %{required(:test) => string(:filled?)}
      end
    end

    test "returns success with a non-empty string", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with an empty string", %{contract: contract} do
      assert {:error, [{:error, {[:test], :filled?, [""]}}]} = contract.conform(%{test: ""})
    end
  end
end
