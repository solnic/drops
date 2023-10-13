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
        %{required(:test) => type([nil, :integer, :string])}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{test: nil}} = contract.conform(%{test: nil})
      assert {:ok, %{test: 312}} = contract.conform(%{test: 312})
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error,
              [
                or: {
                  {:error, {[:test], :type?, [nil, :invalid]}},
                  {:error,
                   [
                     or:
                       {{:error, {[:test], :type?, [:integer, :invalid]}},
                        {:error, {[:test], :type?, [:string, :invalid]}}}
                   ]}
                }
              ]} =
               contract.conform(%{test: :invalid})
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
      assert {:error,
              [
                or:
                  {{:error, {[:test], :type?, [:integer, :invalid]}},
                   {:error, {[:test], :type?, [:string, :invalid]}}}
              ]} =
               contract.conform(%{test: :invalid})

      assert {:error,
              [
                or:
                  {{:error, {[:test], :type?, [:integer, ""]}},
                   {:error, {[:test], :filled?, [""]}}}
              ]} =
               contract.conform(%{test: ""})
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

    test "returns error with invalid data", %{contract: contract} do
      assert {:error,
              [
                or:
                  {{:error, {[:test], :filled?, [[]]}},
                   {:error, {[:test], :type?, [:map, []]}}}
              ]} =
               contract.conform(%{test: []})

      assert {:error,
              [
                or:
                  {{:error, {[:test], :type?, [:list, %{}]}},
                   {:error, {[:test], :filled?, [%{}]}}}
              ]} =
               contract.conform(%{test: %{}})
    end
  end
end
