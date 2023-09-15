defmodule Drops.Contract.ListTest do
  use Drops.ContractCase

  describe "defining a typed list" do
    contract do
      schema do
        %{
          required(:tags) => type(list: [:string])
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{tags: ["red", "green", "blue"]}} =
               contract.conform(%{tags: ["red", "green", "blue"]})
    end

    test "defining required keys with types", %{contract: contract} do
      assert {:error, [{:error, {:string?, [:tags, 1], 312}}]} =
               contract.conform(%{tags: ["red", 312, "blue"]})
    end
  end

  describe "defining a typed list with extra predicates" do
    contract do
      schema do
        %{
          required(:tags) => type(list: [:string, :filled?])
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{tags: ["red", "green", "blue"]}} =
               contract.conform(%{tags: ["red", "green", "blue"]})
    end

    test "defining required keys with types", %{contract: contract} do
      assert {:error, [{:error, {:filled?, [:tags, 1], ""}}]} =
               contract.conform(%{tags: ["red", "", "blue"]})
    end
  end

  describe "defining a typed list with a member schema" do
    contract do
      schema do
        %{
          required(:tags) => type(list: %{
            required(:name) => type(:string)
          })
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{tags: [%{name: "red"}, %{name: "green"}, %{name: "blue"}]}} =
               contract.conform(%{tags: [%{name: "red"}, %{name: "green"}, %{name: "blue"}]})
    end

    test "defining required keys with types", %{contract: contract} do
      assert {:error, [{:error, [{:string?, [:tags, 1, :name], 312}]}]} =
               contract.conform(%{tags: [%{name: "red"}, %{name: 312}, %{name: "blue"}]})
    end
  end
end
