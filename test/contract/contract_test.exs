defmodule DropsTest do
  use ExUnit.Case

  describe "schema" do
    setup(_) do
      on_exit(fn ->
        :code.purge(DropsTest.TestContract)
        :code.delete(DropsTest.TestContract)
      end)
    end

    test "defining required keys with types" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          %{
            required(:name) => type(:string),
            required(:age) => type(:integer)
          }
        end
      end

      assert {:error, [{:error, {:has_key?, :age}}]} =
               TestContract.conform(%{name: "Jane"})

      assert {:ok, %{name: "Jane", age: 21}} =
               TestContract.conform(%{name: "Jane", age: 21})

      assert {:error, [{:error, {:string?, :name, 312}}]} =
               TestContract.conform(%{name: 312, age: 21})

      {:error, result} = TestContract.conform(%{name: 312, age: "21"})

      assert Enum.member?(result, {:error, {:string?, :name, 312}})
      assert Enum.member?(result, {:error, {:integer?, :age, "21"}})
    end

    test "defining required keys with types and extra predicates" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          %{
            required(:name) => type(:string, [:filled?]),
            required(:age) => type(:integer)
          }
        end
      end

      assert {:error, [{:error, {:filled?, :name, ""}}]} =
               TestContract.conform(%{name: "", age: 21})
    end

    test "defining a nested schema - 1 level" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          %{
            required(:user) => %{
              required(:name) => type(:string, [:filled?]),
              required(:age) => type(:integer)
            }
          }
        end
      end

      assert {:error, [{:error, {:has_key?, :user}}]} =
               TestContract.conform(%{})

      assert {:error, [{:error, {:map?, :user, nil}}]} =
               TestContract.conform(%{user: nil})

      assert {:error, [{:error, [{:filled?, [:user, :name], ""}]}]} =
               TestContract.conform(%{user: %{name: "", age: 21}})
    end

    test "defining a nested schema - 2 levels" do
      defmodule TestContract do
        use Drops.Contract

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

      assert {:ok, _} =
               TestContract.conform(%{
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

      assert {:error, [{:error, [[{:filled?, [:user, :address, :street], ""}]]}]} =
               TestContract.conform(%{
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
                {:error,
                 [
                   [{:filled?, [:user, :address, :street], ""}],
                   {:filled?, [:user, :name], ""}
                 ]}
              ]} =
               TestContract.conform(%{
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

    test "defining a schema with rules" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          %{
            required(:name) => type(:string, [:filled?])
          }
        end

        rule(:unique?, [{:ok, {:name, value}}]) do
          case value do
            "John" -> {:error, {:taken, :name, value}}
            _ -> :ok
          end
        end
      end

      assert {:ok, %{name: "Jane"}} = TestContract.conform(%{name: "Jane"})

      assert {:error, [{:error, {:filled?, :name, ""}}]} =
               TestContract.conform(%{name: ""})

      assert {:error, [{:error, {:taken, :name, "John"}}]} =
               TestContract.conform(%{name: "John"})
    end
  end
end
