defmodule Drops.ContractTest do
  use Drops.ContractCase

  describe "required keys with types" do
    contract do
      schema do
        %{
          required(:name) => type(:string),
          required(:age) => type(:integer)
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{name: "Jane", age: 21}} = contract.conform(%{name: "Jane", age: 21})
    end

    test "defining required keys with types", %{contract: contract} do
      assert {:error, [{:error, {:has_key?, [:age]}}]} = contract.conform(%{name: "Jane"})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {:string?, [:name], 312}}]} =
               contract.conform(%{name: 312, age: 21})
    end

    test "returns multiple errors with invalid data", %{contract: contract} do
      {:error, result} = contract.conform(%{name: 312, age: "21"})

      assert Enum.member?(result, {:error, {:string?, [:name], 312}})
      assert Enum.member?(result, {:error, {:integer?, [:age], "21"}})
    end
  end

  describe "required and optionals keys with types" do
    contract do
      schema do
        %{
          required(:email) => type(:string, [:filled?]),
          optional(:name) => type(:string, [:filled?])
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{email: "jane@doe.org", name: "Jane"}} =
               contract.conform(%{email: "jane@doe.org", name: "Jane"})
    end

    test "returns has_key? error when a required key is missing", %{contract: contract} do
      assert {:error, [{:error, {:has_key?, [:email]}}]} = contract.conform(%{})
    end

    test "returns predicate errors", %{contract: contract} do
      assert {:error,
              [{:error, {:filled?, [:name], ""}}, {:error, {:filled?, [:email], ""}}]} =
               contract.conform(%{email: "", name: ""})

      assert {:error, [{:error, {:filled?, [:name], ""}}]} =
               contract.conform(%{email: "jane@doe.org", name: ""})
    end
  end

  describe "required keys with extra predicates" do
    contract do
      schema do
        %{
          required(:name) => type(:string, [:filled?]),
          required(:age) => type(:integer)
        }
      end
    end

    test "returns predicate errors", %{contract: contract} do
      assert {:error, [{:error, {:filled?, [:name], ""}}]} =
               contract.conform(%{name: "", age: 21})
    end
  end

  describe "defining a nested schema - 1 level" do
    contract do
      schema do
        %{
          required(:user) => %{
            required(:name) => type(:string, [:filled?]),
            required(:age) => type(:integer)
          }
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{user: %{name: "John", age: 21}})
    end

    test "returns nested errors", %{contract: contract} do
      assert {:error, [{:error, {:has_key?, [:user]}}]} = contract.conform(%{})

      assert {:error, [{:error, {:map?, [:user], nil}}]} = contract.conform(%{user: nil})

      assert {:error, [{:error, {:filled?, [:user, :name], ""}}]} =
               contract.conform(%{user: %{name: "", age: 21}})
    end
  end

  describe "defining a nested schema - 2 levels" do
    contract do
      schema do
        %{
          required(:user) => %{
            required(:name) => type(:string, [:filled?]),
            required(:age) => type(:integer),
            required(:address) => %{
              required(:city) => type(:string, [:filled?]),
              required(:street) => type(:string, [:filled?]),
              required(:zipcode) => type(:string, [:filled?])
            }
          }
        }
      end
    end

    test "returns deeply nested errors", %{contract: contract} do
      assert {:ok, _} =
               contract.conform(%{
                 user: %{
                   name: "John",
                   age: 21,
                   address: %{
                     city: "New York",
                     street: "Central Park",
                     zipcode: "10001"
                   }
                 }
               })

      assert {:error, [{:error, {:filled?, [:user, :address, :street], ""}}]} =
               contract.conform(%{
                 user: %{
                   name: "John",
                   age: 21,
                   address: %{
                     city: "New York",
                     street: "",
                     zipcode: "10001"
                   }
                 }
               })

      assert {:error,
              [
                {:error, {:filled?, [:user, :address, :street], ""}},
                {:error, {:filled?, [:user, :name], ""}}
              ]} =
               contract.conform(%{
                 user: %{
                   name: "",
                   age: 21,
                   address: %{
                     city: "New York",
                     street: "",
                     zipcode: "10001"
                   }
                 }
               })
    end
  end

  describe "schema with rules" do
    contract do
      schema do
        %{
          required(:name) => type(:string, [:filled?])
        }
      end

      rule(:unique?, [{:ok, {[:name], value}}]) do
        case value do
          "John" -> {:error, {:taken, [:name], value}}
          _ -> :ok
        end
      end
    end

    test "returns success when schema and rules passed", %{contract: contract} do
      assert {:ok, %{name: "Jane"}} = contract.conform(%{name: "Jane"})
    end

    test "returns predicate errors and skips rules", %{contract: contract} do
      assert {:error, [{:error, {:filled?, [:name], ""}}]} = contract.conform(%{name: ""})
    end

    test "returns rule errors", %{contract: contract} do
      assert {:error, [{:error, {:taken, [:name], "John"}}]} =
               contract.conform(%{name: "John"})
    end
  end
end
