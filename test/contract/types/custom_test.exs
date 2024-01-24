defmodule Drops.Contract.Types.CustomTest do
  use Drops.ContractCase

  describe "using a custom primitive type" do
    defmodule Email do
      use Drops.Type, string()
    end

    contract do
      schema do
        %{required(:test) => Email}
      end
    end

    test "returns success with a valid input", %{contract: contract} do
      assert {:ok, %{test: "Hello World"}} = contract.conform(%{test: "Hello World"})
    end

    test "returns errors with invalid input", %{contract: contract} do
      assert_errors(["test must be a string"], contract.conform(%{test: 1}))
    end
  end

  describe "using a custom type with extra predicates" do
    defmodule FilledString do
      use Drops.Type, string(:filled?)
    end

    contract do
      schema do
        %{required(:test) => FilledString}
      end
    end

    test "returns success with a valid input", %{contract: contract} do
      assert {:ok, %{test: "Hello World"}} = contract.conform(%{test: "Hello World"})
    end

    test "returns errors with invalid input", %{contract: contract} do
      assert_errors(["test must be a string"], contract.conform(%{test: 1}))
      assert_errors(["test must be filled"], contract.conform(%{test: ""}))
    end
  end

  describe "using a custom map type" do
    defmodule User do
      use Drops.Type, %{
        required(:name) => string()
      }
    end

    contract do
      schema do
        %{required(:user) => User}
      end
    end

    test "returns success with a valid input", %{contract: contract} do
      assert {:ok, %{user: %{name: "John"}}} = contract.conform(%{user: %{name: "John"}})
    end

    test "returns errors with invalid input", %{contract: contract} do
      assert_errors(["user must be a map"], contract.conform(%{user: 312}))

      assert_errors(
        ["user.name must be a string"],
        contract.conform(%{user: %{name: 312}})
      )
    end
  end
end
