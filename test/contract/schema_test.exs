defmodule Drops.Contract.SchemaTest do
  use Drops.ContractCase

  describe "schema/1 with name" do
    contract do
      schema(:address) do
        %{
          required(:street) => string(),
          required(:city) => string(),
          required(:zip) => string(),
          required(:country) => string()
        }
      end

      schema do
        %{
          required(:name) => string(),
          required(:age) => integer(),
          required(:address) => @schemas.address
        }
      end
    end

    test "defines a named schema", %{contract: contract} do
      assert {:ok,
              %{
                name: "John",
                age: 21,
                address: %{
                  street: "Main St.",
                  city: "New York",
                  zip: "10001",
                  country: "USA"
                }
              }} =
               contract.conform(%{
                 name: "John",
                 age: 21,
                 address: %{
                   street: "Main St.",
                   city: "New York",
                   zip: "10001",
                   country: "USA"
                 }
               })
    end
  end

  describe "schema/1 with name and options" do
    contract do
      schema(:address, atomize: true) do
        %{
          required(:street) => string(),
          required(:city) => string(),
          required(:zip) => string(),
          required(:country) => string()
        }
      end

      schema(atomize: true) do
        %{
          required(:name) => string(),
          required(:age) => integer(),
          required(:address) => @schemas.address
        }
      end
    end

    test "defines a named schema", %{contract: contract} do
      assert {:ok,
              %{
                name: "John",
                age: 21,
                address: %{
                  street: "Main St.",
                  city: "New York",
                  zip: "10001",
                  country: "USA"
                }
              }} =
               contract.conform(%{
                 "name" => "John",
                 "age" => 21,
                 "address" => %{
                   "street" => "Main St.",
                   "city" => "New York",
                   "zip" => "10001",
                   "country" => "USA"
                 }
               })
    end
  end

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
      assert {:error, [{:error, {[], :has_key?, [:age]}}]} =
               contract.conform(%{name: "Jane"})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert {:error, [{:error, {[:name], :type?, [:string, 312]}}]} =
               contract.conform(%{name: 312, age: 21})
    end

    test "returns multiple errors with invalid data", %{contract: contract} do
      {:error, result} = contract.conform(%{name: 312, age: "21"})

      assert Enum.member?(result, {:error, {[:name], :type?, [:string, 312]}})
      assert Enum.member?(result, {:error, {[:age], :type?, [:integer, "21"]}})
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
      assert {:error, [{:error, {[], :has_key?, [:email]}}]} = contract.conform(%{})
    end

    test "returns predicate errors", %{contract: contract} do
      assert {:error,
              [{:error, {[:name], :filled?, [""]}}, {:error, {[:email], :filled?, [""]}}]} =
               contract.conform(%{email: "", name: ""})

      assert {:error, [{:error, {[:name], :filled?, [""]}}]} =
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
      assert {:error, [{:error, {[:name], :filled?, [""]}}]} =
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
      assert {:error, [{:error, {[], :has_key?, [:user]}}]} = contract.conform(%{})

      assert {:error, [{:error, {[:user], :type?, [:map, nil]}}]} =
               contract.conform(%{user: nil})

      assert {:error, [{:error, {[:user, :name], :filled?, [""]}}]} =
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

    test "returns success when valid", %{contract: contract} do
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
    end

    test "returns deeply nested errors", %{contract: contract} do
      assert {:error, [{:error, {[:user, :address, :street], :filled?, [""]}}]} =
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
                {:error, {[:user, :address, :street], :filled?, [""]}},
                {:error, {[:user, :name], :filled?, [""]}}
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

  describe "schema for string maps" do
    contract do
      schema(atomize: true) do
        %{
          required(:user) => %{
            required(:name) => type(:string, [:filled?]),
            required(:age) => type(:integer),
            required(:address) => %{
              required(:city) => type(:string, [:filled?]),
              required(:street) => type(:string, [:filled?]),
              required(:zipcode) => type(:string, [:filled?])
            }
          },
          optional(:company) => %{
            required(:name) => type(:string)
          }
        }
      end
    end

    test "returns success when schema validation passed", %{contract: contract} do
      expected_output = %{
        user: %{
          name: "John",
          age: 21,
          address: %{
            city: "New York",
            street: "Central Park",
            zipcode: "10001"
          }
        }
      }

      assert {:ok, output} =
               contract.conform(%{
                 "user" => %{
                   "name" => "John",
                   "age" => 21,
                   "address" => %{
                     "city" => "New York",
                     "street" => "Central Park",
                     "zipcode" => "10001"
                   }
                 }
               })

      assert expected_output == output

      expected_output = %{
        user: %{
          name: "John",
          age: 21,
          address: %{
            city: "New York",
            street: "Central Park",
            zipcode: "10001"
          }
        },
        company: %{
          name: "Elixir Drops"
        }
      }

      assert {:ok, output} =
               contract.conform(%{
                 "user" => %{
                   "name" => "John",
                   "age" => 21,
                   "address" => %{
                     "city" => "New York",
                     "street" => "Central Park",
                     "zipcode" => "10001"
                   }
                 },
                 "company" => %{
                   "name" => "Elixir Drops"
                 }
               })

      assert expected_output == output

      assert {:error,
              [
                {:error, {[:user, :address, :street], :filled?, [""]}},
                {:error, {[:user, :name], :filled?, [""]}}
              ]} =
               contract.conform(%{
                 "user" => %{
                   "name" => "",
                   "age" => 21,
                   "address" => %{
                     "city" => "New York",
                     "street" => "",
                     "zipcode" => "10001"
                   }
                 }
               })
    end
  end

  describe "using list shortcut for sum types" do
    contract do
      schema(:left) do
        %{required(:name) => string()}
      end

      schema(:right) do
        %{required(:login) => string()}
      end

      schema do
        %{
          required(:user) => [@schemas.left, @schemas.right]
        }
      end
    end

    test "returns success when either of the schemas passed", %{contract: contract} do
      assert {:ok, %{user: %{name: "John Doe"}}} =
               contract.conform(%{user: %{name: "John Doe"}})
    end

    test "returns error when both schemas didn't pass", %{contract: contract} do
      assert {:error,
              [
                or:
                  {{:error, [error: {[:user], :has_key?, [:name]}]},
                   {:error, [error: {[:user], :has_key?, [:login]}]}}
              ]} =
               contract.conform(%{user: %{}})
    end
  end

  describe "sum of schemas" do
    contract do
      schema(:left) do
        %{required(:name) => string()}
      end

      schema(:right) do
        %{required(:login) => string()}
      end

      schema do
        [@schemas.left, @schemas.right]
      end
    end

    test "returns success when either of the schemas passed", %{contract: contract} do
      assert {:ok, %{name: "John Doe"}} = contract.conform(%{name: "John Doe"})
      assert {:ok, %{login: "john"}} = contract.conform(%{login: "john"})
    end

    test "returns error when both schemas didn't pass", %{contract: contract} do
      assert {:error,
              {:or,
               {{:error, [error: {[], :has_key?, [:name]}]},
                {:error, [error: {[], :has_key?, [:login]}]}}}} = contract.conform(%{})
    end
  end
end
