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
      assert_errors(["test must be an integer"], contract.conform(%{test: :invalid}))
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
      assert_errors(["test must be an integer"], contract.conform(%{test: :invalid}))
      assert_errors(["test must be odd"], contract.conform(%{test: 312}))
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
      assert_errors(["test must be an integer"], contract.conform(%{test: :invalid}))
      assert_errors(["test must be greater than 2"], contract.conform(%{test: 0}))
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
      assert_errors(["test must be an integer"], contract.conform(%{test: :invalid}))
      assert_errors(["test must be even"], contract.conform(%{test: 311}))
      assert_errors(["test must be greater than 2"], contract.conform(%{test: 0}))
    end
  end
end
