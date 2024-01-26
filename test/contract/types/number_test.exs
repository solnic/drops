defmodule Drops.Contract.Types.NumberTest do
  use Drops.ContractCase

  describe "number/0" do
    contract do
      schema do
        %{required(:test) => number()}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(["test must be a number"], contract.conform(%{test: :invalid}))
    end
  end

  describe "number/1 with an extra predicate" do
    contract do
      schema do
        %{required(:test) => number(:odd?)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 311}} = contract.conform(%{test: 311})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(["test must be a number"], contract.conform(%{test: :invalid}))
      assert_errors(["test must be odd"], contract.conform(%{test: 312}))
    end
  end

  describe "number/1 with an extra predicate with args" do
    contract do
      schema do
        %{required(:test) => number(gt?: 2)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(["test must be a number"], contract.conform(%{test: :invalid}))
      assert_errors(["test must be greater than 2"], contract.conform(%{test: 0}))
    end
  end

  describe "number/1 with extra predicates" do
    contract do
      schema do
        %{required(:test) => number([:even?, gt?: 2])}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(["test must be a number"], contract.conform(%{test: :invalid}))
      assert_errors(["test must be even"], contract.conform(%{test: 311}))
      assert_errors(["test must be greater than 2"], contract.conform(%{test: 0}))
    end
  end
end
