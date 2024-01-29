defmodule Drops.Contract.Types.StringTest do
  use Drops.ContractCase

  describe "a union of two primitive types" do
    contract do
      schema do
        %{required(:test) => union([string(), integer()])}
      end
    end

    test "returns success when left side is a success", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "Hello"})
    end

    test "returns success when right side is a success", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: 312})
    end

    test "returns error when left side and right are failures", %{contract: contract} do
      assert_errors(
        ["test must be a string or test must be an integer"],
        contract.conform(%{test: []})
      )
    end
  end

  describe "a union of two primitive types when left side is constrained" do
    contract do
      schema do
        %{required(:test) => union([string(size?: 5), integer()])}
      end
    end

    test "returns success when left side is a success", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "Hello"})
    end

    test "returns success when right side is a success", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: 312})
    end

    test "returns error when left side is a failure", %{contract: contract} do
      assert_errors(
        ["test size must be 5 or test must be an integer"],
        contract.conform(%{test: "Hello World"})
      )
    end

    test "returns error when left side and right are failures", %{contract: contract} do
      assert_errors(
        ["test must be a string or test must be an integer"],
        contract.conform(%{test: []})
      )
    end
  end

  describe "a union of two primitive types when right side is constrained" do
    contract do
      schema do
        %{required(:test) => union([string(), integer(gt?: 0)])}
      end
    end

    test "returns success when left side is a success", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "Hello"})
    end

    test "returns success when right side is a success", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: 312})
    end

    test "returns success when right side is a failure", %{contract: contract} do
      assert_errors(
        ["test must be a string or test must be greater than 0"],
        contract.conform(%{test: -3})
      )
    end

    test "returns error when left side and right are failures", %{contract: contract} do
      assert_errors(
        ["test must be a string or test must be an integer"],
        contract.conform(%{test: []})
      )
    end
  end

  describe "a union of two primitive types when both sides are constrained" do
    contract do
      schema do
        %{required(:test) => union([string(size?: 5), integer(gt?: 0)])}
      end
    end

    test "returns success when left side is a success", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "Hello"})
    end

    test "returns success when right side is a success", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: 312})
    end

    test "returns error when left side is a failure", %{contract: contract} do
      assert_errors(
        ["test size must be 5 or test must be an integer"],
        contract.conform(%{test: "Hello World"})
      )
    end

    test "returns success when right side is a failure", %{contract: contract} do
      assert_errors(
        ["test must be a string or test must be greater than 0"],
        contract.conform(%{test: -3})
      )
    end

    test "returns error when left side and right are failures", %{contract: contract} do
      assert_errors(
        ["test must be a string or test must be an integer"],
        contract.conform(%{test: []})
      )
    end
  end
end
