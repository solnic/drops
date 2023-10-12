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
      assert {:error,
              [
                error:
                  {:or,
                   {{:error, {[:test], :type?, [nil, 312]}},
                    {:error, {[:test], :type?, [:string, 312]}}}}
              ]} =
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
      assert {:error,
              [
                {:error,
                 {:or,
                  {{:error, {[:test], :type?, [nil, 312]}},
                   {:error, {[:test], :type?, [:string, 312]}}}}}
              ]} =
               contract.conform(%{test: 312})
    end

    test "returns error when extra predicates fail", %{contract: contract} do
      assert {:error,
              [
                {:error,
                 {:or,
                  {{:error, {[:test], :type?, [nil, ""]}},
                   {:error, {[:test], :filled?, [""]}}}}}
              ]} =
               contract.conform(%{test: ""})
    end
  end

  describe "maybe/1 with :map when atomized" do
    contract do
      schema(atomize: true) do
        %{
          required(:test) => maybe(:map),
          optional(:user) => %{required(:name) => type(:string)}
        }
      end
    end

    test "returns success with nil", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{"test" => nil, "user" => %{"name" => "John"}})
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{"test" => %{}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert {:error,
              [
                {:error,
                 {:or,
                  {{:error, {[:test], :type?, [nil, 312]}},
                   {:error, {[:test], :type?, [:map, 312]}}}}}
              ]} =
               contract.conform(%{"test" => 312})
    end
  end

  describe "maybe/1 with :map" do
    contract do
      schema do
        %{required(:test) => maybe(:map)}
      end
    end

    test "returns success with nil", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: nil})
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: %{}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert {:error,
              [
                {:error,
                 {:or,
                  {{:error, {[:test], :type?, [nil, 312]}},
                   {:error, {[:test], :type?, [:map, 312]}}}}}
              ]} =
               contract.conform(%{test: 312})
    end
  end

  describe "maybe/1 with a schema" do
    contract do
      schema do
        %{
          required(:test) =>
            maybe(%{
              required(:name) => string()
            })
        }
      end
    end

    test "returns success with nil", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: nil})
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: %{name: "hello"}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert {:error,
              [
                {:error,
                 {:or,
                  {{:error, {[:test], :type?, [nil, 312]}},
                   {:error, {[:test], :type?, [:map, 312]}}}}}
              ]} =
               contract.conform(%{test: 312})
    end
  end
end
