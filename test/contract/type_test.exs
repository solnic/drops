defmodule Drops.Contract.TypeTest do
  use Drops.ContractCase

  describe "type/1 with a type atom" do
    contract do
      schema do
        %{required(:test) => type(:string)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:string, 312]}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "type/1 with two types" do
    contract do
      schema do
        %{required(:test) => type([:nil, :integer, :string])}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: nil}} = contract.conform(%{test: nil})
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:string, :invalid]}}]} =
               contract.conform(%{test: :invalid})
    end
  end

  describe "type/1 with multiple types and extra predicates" do
    contract do
      schema do
        %{required(:test) => type([:integer, {:string, [:filled?]}])}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:string, :invalid]}}]} =
               contract.conform(%{test: :invalid})

      assert {:error, [{:error, {[:test], :filled?, [""]}}]} =
               contract.conform(%{test: ""})
    end
  end
end
