defmodule Drops.Type.CustomMapTest do
  use Drops.ContractCase

  describe "use/1 with a custom map" do
    defmodule User do
      use Drops.Type, %{required(:name) => string(), required(:age) => integer()}
    end

    contract do
      schema do
        %{
          required(:user) => User
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{user: %{name: "Jane", age: 42}}} =
               contract.conform(%{user: %{name: "Jane", age: 42}})
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(
        ["user.age must be an integer"],
        contract.conform(%{user: %{name: "Jane", age: "42"}})
      )
    end
  end

  describe "use/1 with a custom map in an atomized list" do
    defmodule AtomizedUser do
      use Drops.Type, %{required(:name) => string(), required(:age) => integer()}
    end

    contract do
      schema(atomize: true) do
        %{
          required(:users) => list(AtomizedUser)
        }
      end
    end

    test "returns success with valid data", %{contract: contract} do
      assert {:ok, %{users: [%{name: "Jane", age: 42}]}} =
               contract.conform(%{
                 "users" => [%{"name" => "Jane", "age" => 42}]
               })
    end

    test "returns error with invalid data", %{contract: contract} do
      assert_errors(
        ["users.0.age must be an integer"],
        contract.conform(%{
          "users" => [%{"name" => "Jane", "age" => "42"}]
        })
      )
    end
  end
end
