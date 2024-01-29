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
      assert_errors(["test must be a string"], contract.conform(%{test: 312}))
    end
  end

  describe "type/1 with two types" do
    contract do
      schema do
        %{required(:test) => type([nil, :integer, :string])}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: nil}} = contract.conform(%{test: nil})
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(
        ["test must be nil or test must be an integer or test must be a string"],
        contract.conform(%{test: :invalid})
      )
    end
  end

  describe "type/1 with multiple types and extra predicates per type" do
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
      assert_errors(
        ["test must be an integer or test must be a string"],
        contract.conform(%{test: :invalid})
      )

      assert_errors(
        ["test must be an integer or test must be filled"],
        contract.conform(%{test: ""})
      )
    end
  end

  describe "type/1 with multiple types and extra predicates for all types" do
    contract do
      schema do
        %{required(:test) => type([:list, :map], [:filled?])}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: [1, 2, 3]}} = contract.conform(%{test: [1, 2, 3]})
      assert {:ok, %{test: %{a: 1, b: 2}}} = contract.conform(%{test: %{a: 1, b: 2}})
    end

    test "returns error from left predicates", %{contract: contract} do
      assert_errors(["test must be filled"], contract.conform(%{test: []}))
    end

    test "returns errors from right predicates", %{contract: contract} do
      assert_errors(
        ["test must be a list or test must be filled"],
        contract.conform(%{test: %{}})
      )
    end
  end

  describe "type/1 with a type atom and options" do
    contract do
      schema do
        %{required(:test) => opts(type(:string, [:filled?]), name: :test_name)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      [key] = contract.schema().keys
      %{opts: opts} = key.type

      assert Keyword.get(opts, :name) == :test_name
    end
  end
end
