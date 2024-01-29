defmodule Drops.Contract.Types.StringTest do
  use Drops.ContractCase

  describe "string/0" do
    contract do
      schema do
        %{required(:test) => string()}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "Hello"})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert_errors(["test must be a string"], contract.conform(%{test: 312}))
    end
  end

  describe "string/1 with extra predicates" do
    contract do
      schema do
        %{required(:test) => string(:filled?)}
      end
    end

    test "returns success with a non-empty string", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with an empty string", %{contract: contract} do
      assert_errors(["test must be filled"], contract.conform(%{test: ""}))
    end
  end

  describe "string/1 with a type atom and options" do
    contract do
      schema do
        %{required(:test) => opts(string(:filled?), name: :test_name)}
      end
    end

    test "returns success with valid data", %{contract: contract} do
      [key] = contract.schema().keys
      %{opts: opts} = key.type

      assert Keyword.get(opts, :name) == :test_name
    end
  end
end
