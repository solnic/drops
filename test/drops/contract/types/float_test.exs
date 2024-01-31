defmodule Drops.Contract.Types.FloatTest do
  use Drops.ContractCase

  describe "float/0" do
    contract do
      schema do
        %{required(:test) => float()}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 31.2}} = contract.conform(%{test: 31.2})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(["test must be a float"], contract.conform(%{test: "hello"}))
    end
  end

  describe "float/1 with an extra predicate" do
    contract do
      schema do
        %{required(:test) => float(gt?: 10)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 31.2}} = contract.conform(%{test: 31.2})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(["test must be a float"], contract.conform(%{test: :invalid}))
      assert_errors(["test must be greater than 10"], contract.conform(%{test: 3.2}))
    end
  end

  describe "float/1 with extra predicates" do
    contract do
      schema do
        %{required(:test) => float(gt?: 0, lt?: 100)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: 31.2}} = contract.conform(%{test: 31.2})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(["test must be a float"], contract.conform(%{test: :invalid}))
      assert_errors(["test must be less than 100"], contract.conform(%{test: 200.0}))
      assert_errors(["test must be greater than 0"], contract.conform(%{test: 0.0}))
    end
  end
end
