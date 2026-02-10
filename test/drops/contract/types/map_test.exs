defmodule Drops.Contract.Types.MapTest do
  use Drops.ContractCase

  describe "map/0" do
    contract do
      schema do
        %{required(:test) => map()}
      end
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: %{}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert_errors(["test must be a map"], contract.conform(%{test: 312}))
    end
  end

  describe "map/1 with extra predicates" do
    contract do
      schema do
        %{required(:test) => map(:filled?)}
      end
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: %{hello: "World"}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert_errors(["test must be a map"], contract.conform(%{test: 312}))
    end
  end

  describe "map/1 with type specification" do
    contract do
      schema do
        %{
          optional(:string_to_string) => map(keys: string(), values: string()),
          optional(:string_to_integer_as_string) => map(keys: string(), values: cast(:string) |> integer()),
          optional(:even_integer_to_filled_string) => map(keys: integer(:even?), values: string(:filled?)),
          optional(:nested_map) => map(keys: string(), values: map(keys: string(), values: list(string())))
        }
      end
    end

    test "returns success with maps with correct types", %{contract: contract} do
      assert {:ok, %{
               string_to_string: %{"Hello" => "World", "foo" => "bar"},
               string_to_integer_as_string: %{"foo" => 1, "bar" => 2},
               even_integer_to_filled_string: %{2 => "baz"},
               nested_map: %{"parent" => %{"child" => ["grandchild1", "grandchild2"]}}
             }} ==
               contract.conform(
                 %{
                   string_to_string: %{"Hello" => "World", "foo" => "bar"},
                   string_to_integer_as_string: %{"foo" => "1", "bar" => "2"},
                   even_integer_to_filled_string: %{2 => "baz"},
                   nested_map: %{"parent" => %{"child" => ["grandchild1", "grandchild2"]}}
                 }
               )
    end

    test "returns error with non-string => string", %{contract: contract} do
      assert_errors(
        ["string_to_string.1 must be a string"],
        contract.conform(%{string_to_string: %{1 => "foo"}})
      )
    end

    test "returns error with string => non-string", %{contract: contract} do
      assert_errors(
        ["string_to_string.foo must be a string"],
        contract.conform(%{string_to_string: %{"foo" => true}})
      )
    end

    test "returns error with odd integer => string", %{contract: contract} do
      assert_errors(
        ["even_integer_to_filled_string.1 must be even"],
        contract.conform(%{even_integer_to_filled_string: %{1 => "foo"}})
      )
    end

    test "returns error with even integer => empty string", %{contract: contract} do
      assert_errors(
        ["even_integer_to_filled_string.2 must be filled"],
        contract.conform(%{even_integer_to_filled_string: %{2 => ""}})
      )
    end

    test "returns error with string => non-map", %{contract: contract} do
      assert_errors(
        ["nested_map.Hello must be a map"],
        contract.conform(%{nested_map: %{"Hello" => "World!"}})
      )
    end

    test "returns error with string => map with wrong types", %{contract: contract} do
      assert_errors(
        ["nested_map.parent.child must be a list"],
        contract.conform(%{nested_map: %{"parent" => %{"child" => "grandchild"}}})
      )
    end
  end
end
