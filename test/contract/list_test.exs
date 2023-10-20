defmodule Drops.Contract.ListTest do
  use Drops.ContractCase

  describe "defining a typed list" do
    contract do
      schema do
        %{
          required(:tags) => list(:string)
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{tags: ["red", "green", "blue"]}} =
               contract.conform(%{tags: ["red", "green", "blue"]})
    end

    test "defining required keys with types", %{contract: contract} do
      assert_errors(
        ["tags.1 must be a string"],
        contract.conform(%{tags: ["red", 312, "blue"]})
      )
    end
  end

  describe "defining a typed list with extra predicates" do
    contract do
      schema do
        %{
          required(:tags) => list(:string, [:filled?])
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{tags: ["red", "green", "blue"]}} =
               contract.conform(%{tags: ["red", "green", "blue"]})
    end

    test "defining required keys with types", %{contract: contract} do
      assert_errors(
        ["tags.1 must be filled"],
        contract.conform(%{tags: ["red", "", "blue"]})
      )
    end
  end

  describe "defining a typed list with a member schema" do
    contract do
      schema do
        %{
          required(:tags) =>
            list(%{
              required(:name) => type(:string)
            })
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{tags: [%{name: "red"}, %{name: "green"}, %{name: "blue"}]}} =
               contract.conform(%{
                 tags: [%{name: "red"}, %{name: "green"}, %{name: "blue"}]
               })
    end

    test "defining required keys with types", %{contract: contract} do
      assert_errors(
        ["tags.1.name must be a string"],
        contract.conform(%{tags: [%{name: "red"}, %{name: 312}, %{name: "blue"}]})
      )
    end
  end

  describe "defining an atomized typed list with a member schema" do
    contract do
      schema(atomize: true) do
        %{
          required(:tags) =>
            list(%{
              required(:name) => type(:string)
            })
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{tags: [%{name: "red"}, %{name: "green"}, %{name: "blue"}]}} =
               contract.conform(%{
                 "tags" => [%{"name" => "red"}, %{"name" => "green"}, %{"name" => "blue"}]
               })
    end

    test "defining required keys with types", %{contract: contract} do
      assert_errors(
        ["tags.1.name must be a string"],
        contract.conform(%{
          "tags" => [%{"name" => "red"}, %{"name" => 312}, %{"name" => "blue"}]
        })
      )
    end
  end

  describe "defining a list of lists and a primitive member type" do
    contract do
      schema(atomize: true) do
        %{
          required(:tags) => list(list(:string))
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{tags: [["red"], ["green"], ["blue"]]}} =
               contract.conform(%{"tags" => [["red"], ["green"], ["blue"]]})
    end

    test "defining required keys with types", %{contract: contract} do
      assert_errors(
        ["tags.1.0 must be a string"],
        contract.conform(%{"tags" => [["red"], [312], ["blue"]]})
      )
    end
  end

  describe "defining a list of lists and a schema member type" do
    contract do
      schema(atomize: true) do
        %{
          required(:tags) =>
            list(
              list(%{
                required(:name) => type(:string)
              })
            )
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert_errors(
        ["tags.1.0.name must be a string"],
        contract.conform(%{
          "tags" => [
            [%{"name" => "red"}],
            [%{"name" => 312}],
            [%{"name" => "blue"}]
          ]
        })
      )
    end

    test "defining required keys with types", %{contract: contract} do
      assert_errors(
        ["tags.1.0.name must be a string"],
        contract.conform(%{
          "tags" => [
            [%{"name" => "red"}],
            [%{"name" => 312}],
            [%{"name" => "blue"}]
          ]
        })
      )
    end
  end
end
