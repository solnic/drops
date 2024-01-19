defmodule Drops.Validator.MessagesTest do
  use Drops.ContractCase

  doctest Drops.Validator.Messages.Backend

  describe "errors/1 with key errors" do
    contract do
      schema do
        %{
          required(:name) => string(:filled?),
          required(:age) => integer(gt?: 18)
        }
      end
    end

    test "returns errors from the has_key? predicate", %{contract: contract} do
      assert {:error, [error = %{path: path, meta: meta}]} =
               contract.conform(%{name: "Jane Doe"})

      assert path == [:age]
      assert meta == [predicate: :has_key?, args: []]
      assert to_string(error) == "age key must be present"
    end
  end

  describe "errors/1" do
    contract do
      schema do
        %{
          optional(:name) => string(:filled?),
          optional(:age) => integer(gt?: 18),
          optional(:role) => string(in?: ["admin", "user"]),
          optional(:birthday) => maybe(:date)
        }
      end
    end

    test "returns errors from a type? predicate", %{contract: contract} do
      assert {:error, [error = %{path: path, meta: meta}]} =
               contract.conform(%{name: "Jane Doe", age: "twenty"})

      assert path == [:age]
      assert meta == [predicate: :type?, args: [:integer, "twenty"]]
      assert to_string(error) == "age must be an integer"
    end

    test "returns errors from a predicate with no args", %{contract: contract} do
      assert {:error, [error = %{path: path, meta: meta}]} =
               contract.conform(%{name: "", age: 21})

      assert path == [:name]
      assert meta == [predicate: :filled?, args: [""]]
      assert to_string(error) == "name must be filled"
    end

    test "returns errors from a predicate with args", %{contract: contract} do
      assert {:error, [error = %{path: path, meta: meta}]} =
               contract.conform(%{name: "Jane", age: 12})

      assert path == [:age]
      assert meta == [predicate: :gt?, args: [18, 12]]
      assert to_string(error) == "age must be greater than 18"
    end

    test "returns errors from in? with a list of valid values", %{contract: contract} do
      assert {:error, [error = %{path: path, meta: meta}]} =
               contract.conform(%{name: "Jane", age: 19, role: "oops"})

      assert path == [:role]
      assert meta == [predicate: :in?, args: [["admin", "user"], "oops"]]
      assert to_string(error) == "role must be one of: admin, user"
    end

    test "returns errors from a sum type", %{contract: contract} do
      assert {:error, [error = %{left: left_error, right: right_error}]} =
               contract.conform(%{birthday: "oops"})

      assert left_error.path == [:birthday]
      assert left_error.meta == [predicate: :type?, args: [nil, "oops"]]

      assert right_error.path == [:birthday]
      assert right_error.meta == [predicate: :type?, args: [:date, "oops"]]

      assert to_string(error) == "birthday must be nil or birthday must be a date"
    end
  end

  describe "errors/1 with a nested schema" do
    contract do
      schema do
        %{
          required(:user) => %{
            optional(:name) => string(:filled?),
            optional(:age) => integer(gt?: 18),
            optional(:roles) => list(:string)
          }
        }
      end
    end

    test "returns errors from a type? predicate", %{contract: contract} do
      assert {:error, [error = %{path: path, meta: meta}]} =
               contract.conform(%{user: %{age: "twenty"}})

      assert path == [:user, :age]
      assert meta == [predicate: :type?, args: [:integer, "twenty"]]
      assert to_string(error) == "user.age must be an integer"
    end

    test "returns errors from a list type", %{contract: contract} do
      assert {:error, [%{errors: [error = %{path: path, meta: meta}]}]} =
               contract.conform(%{user: %{roles: ["admin", 312, "moderator"]}})

      assert path == [:user, :roles, 1]
      assert meta == [predicate: :type?, args: [:string, 312]]
      assert to_string(error) == "user.roles.1 must be a string"
    end
  end
end
