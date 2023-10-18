defmodule Drops.Contract.MessagesTest do
  use Drops.ContractCase

  doctest Drops.Contract.Messages.Backend

  describe "errors/1" do
    contract do
      schema do
        %{
          required(:name) => string(:filled?),
          required(:age) => integer(gt?: 18),
          optional(:role) => string(in?: ["admin", "user"])
        }
      end
    end

    test "returns errors from a type? predicate", %{contract: contract} do
      result = contract.conform(%{name: "Jane Doe", age: "twenty"})

      assert [error = %{path: path, meta: meta}] = contract.errors(result)

      assert path == [:age]
      assert meta == %{predicate: :type?, args: [:integer, "twenty"]}
      assert to_string(error) == "age must be an integer"
    end

    test "returns errors from a predicate with no args", %{contract: contract} do
      result = contract.conform(%{name: "", age: 21})

      assert [error = %{path: path, meta: meta}] = contract.errors(result)

      assert path == [:name]
      assert meta == %{predicate: :filled?, args: [""]}
      assert to_string(error) == "name must be filled"
    end

    test "returns errors from a predicate with args", %{contract: contract} do
      result = contract.conform(%{name: "Jane", age: 12})

      assert [error = %{path: path, meta: meta}] = contract.errors(result)

      assert path == [:age]
      assert meta == %{predicate: :gt?, args: [18, 12]}
      assert to_string(error) == "age must be greater than 18"
    end

    test "returns errors from in? with a list of valid values", %{contract: contract} do
      result = contract.conform(%{name: "Jane", age: 19, role: "oops"})

      assert [error = %{path: path, meta: meta}] = contract.errors(result)

      assert path == [:role]
      assert meta == %{predicate: :in?, args: [["admin", "user"], "oops"]}
      assert to_string(error) == "role must be one of: admin, user"
    end
  end
end
