defmodule Drops.Contract.Types.IntegerTest do
  use Drops.ContractCase

  describe "integer/0" do
    contract do
      schema do
        %{required(:test) => integer()}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:integer, :invalid]}}]} =
               contract.conform(%{test: :invalid})
    end
  end

  describe "integer/1 with an extra predicate" do
    contract do
      schema do
        %{required(:test) => integer(:odd?)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 311}} = contract.conform(%{test: 311})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:integer, :invalid]}}]} =
               contract.conform(%{test: :invalid})

      assert {:error, [{:error, {[:test], :odd?, [312]}}]} =
               contract.conform(%{test: 312})
    end
  end

  describe "integer/1 with an extra predicate with args" do
    contract do
      schema do
        %{required(:test) => integer(gt?: 2)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:integer, :invalid]}}]} =
               contract.conform(%{test: :invalid})

      assert {:error, [{:error, {[:test], :gt?, [2, 0]}}]} =
               contract.conform(%{test: 0})
    end
  end

  describe "integer/1 with extra predicates" do
    contract do
      schema do
        %{required(:test) => integer([:even?, gt?: 2])}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {[:test], :type?, [:integer, :invalid]}}]} =
               contract.conform(%{test: :invalid})

      assert {:error, [{:error, {[:test], :even?, [7]}}]} =
               contract.conform(%{test: 7})

      assert {:error, [{:error, {[:test], :gt?, [2, 0]}}]} =
               contract.conform(%{test: 0})
    end
  end
end
