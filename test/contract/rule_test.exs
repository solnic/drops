defmodule Drops.Contract.RuleTest do
  use Drops.ContractCase

  describe "rule/1 with a flat map and a single key" do
    contract do
      schema do
        %{
          required(:name) => type(:string, [:filled?]),
          optional(:age) => type(:integer)
        }
      end

      rule(:unique?, %{name: name}) do
        case name do
          "John" -> {:error, {[:user, :name], :taken}}
          _ -> :ok
        end
      end
    end

    test "returns success when schema and rules passed", %{contract: contract} do
      assert {:ok, %{name: "Jane"}} = contract.conform(%{name: "Jane"})
    end

    test "returns predicate errors and skips rules", %{contract: contract} do
      assert_errors(["name must be filled"], contract.conform(%{name: ""}))
    end

    test "returns rule errors", %{contract: contract} do
      assert_errors(["user.name taken"], contract.conform(%{name: "John"}))
    end
  end

  describe "rule/1 with a nested map" do
    contract do
      schema do
        %{
          required(:user) => %{
            required(:name) => type(:string, [:filled?]),
            optional(:age) => type(:integer)
          }
        }
      end

      rule(:unique?, %{user: %{name: name}}) do
        case name do
          "John" -> {:error, {[:user, :name], :taken}}
          _ -> :ok
        end
      end
    end

    test "returns success when schema and rules passed", %{contract: contract} do
      assert {:ok, %{user: %{name: "Jane"}}} = contract.conform(%{user: %{name: "Jane"}})
    end

    test "returns predicate errors and skips rules", %{contract: contract} do
      assert_errors(["user must be a map"], contract.conform(%{user: ""}))
      assert_errors(["user.name must be filled"], contract.conform(%{user: %{name: ""}}))
    end

    test "returns rule errors", %{contract: contract} do
      assert_errors(["user.name taken"], contract.conform(%{user: %{name: "John"}}))
    end
  end

  describe "rule/1 with multiple rules defined" do
    contract do
      schema do
        %{
          required(:login) => maybe(:string, [:filled?]),
          required(:email) => maybe(:string, [:filled?])
        }
      end

      rule(:auth_required, %{login: nil, email: nil}) do
        {:error, "either login or email required"}
      end

      rule(:unique_email, %{email: "john@doe.org"}) do
        {:error, {:taken, [:email], "john@doe.org"}}
      end
    end

    test "returns success when schema and rules passed", %{contract: contract} do
      assert {:ok, %{login: "jane"}} = contract.conform(%{login: "jane", email: nil})

      assert {:ok, %{email: "jane@doe.org"}} =
               contract.conform(%{login: nil, email: "jane@doe.org"})
    end

    test "returns predicate errors and skips rules", %{contract: contract} do
      assert_errors(
        ["login must be nil or login must be filled"],
        contract.conform(%{login: "", email: nil})
      )
    end

    test "returns rule errors", %{contract: contract} do
      assert_errors(
        ["either login or email required"],
        contract.conform(%{login: nil, email: nil})
      )
    end
  end

  describe "rule/1 for the whole input" do
    contract do
      schema do
        %{
          optional(:login) => maybe(:string, [:filled?]),
          optional(:email) => maybe(:string, [:filled?])
        }
      end

      rule(:auth_required, data) do
        if is_nil(data[:login]) and is_nil(data[:email]) do
          {:error, "either login or email required"}
        else
          :ok
        end
      end
    end

    test "returns success when schema and rules passed", %{contract: contract} do
      assert {:ok, %{login: "jane"}} = contract.conform(%{login: "jane", email: nil})

      assert {:ok, %{email: "jane@doe.org"}} =
               contract.conform(%{login: nil, email: "jane@doe.org"})
    end

    test "returns rule errors", %{contract: contract} do
      assert_errors(
        ["either login or email required"],
        contract.conform(%{login: nil, email: nil})
      )
    end
  end

  describe "rule/1 for the whole input when nested" do
    contract do
      schema do
        %{
          required(:name) => string(),
          optional(:contact) => %{
            required(:email) => string()
          },
          optional(:address) => %{
            required(:street) => string(),
            required(:city) => string(),
            required(:country) => string(),
            required(:zipcode) => string()
          }
        }
      end

      rule(:info_required, data) do
        if is_nil(data[:contact]) and is_nil(data[:address]) do
          {:error, "either contact or address info is required"}
        else
          :ok
        end
      end
    end

    test "returns success when schema and rules passed", %{contract: contract} do
      assert {:ok, %{name: "jane", contact: %{email: "jane@doe.org"}}} =
               contract.conform(%{name: "jane", contact: %{email: "jane@doe.org"}})

      assert {:ok,
              %{
                name: "jane",
                address: %{street: "Main St", city: "NY", country: "US", zipcode: "12345"}
              }} =
               contract.conform(%{
                 name: "jane",
                 address: %{
                   street: "Main St",
                   city: "NY",
                   country: "US",
                   zipcode: "12345"
                 }
               })
    end

    test "returns rule errors", %{contract: contract} do
      assert_errors(
        ["either contact or address info is required"],
        contract.conform(%{name: "jane"})
      )
    end
  end
end
