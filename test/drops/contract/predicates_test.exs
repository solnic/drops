defmodule Drops.PredicatesTest do
  use Drops.ContractCase

  doctest Drops.Predicates

  describe "type?/2 with :nil" do
    contract do
      schema do
        %{required(:test) => type(nil)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: nil})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert_errors(["test must be nil"], contract.conform(%{test: 312}))
    end
  end

  describe "type?/2 with :atom" do
    contract do
      schema do
        %{required(:test) => type(:atom)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: :hello})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert_errors(["test must be an atom"], contract.conform(%{test: 312}))
    end
  end

  describe "type?/2 with :string" do
    contract do
      schema do
        %{required(:test) => type(:string)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: "Hello"})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert_errors(["test must be a string"], contract.conform(%{test: 312}))
    end
  end

  describe "type?/2 with :integer" do
    contract do
      schema do
        %{required(:test) => type(:integer)}
      end
    end

    test "returns success with an integer value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: 312})
    end

    test "returns error with a non-integer value", %{contract: contract} do
      assert_errors(["test must be an integer"], contract.conform(%{test: "Hello"}))
    end
  end

  describe "type?/2 with :float" do
    contract do
      schema do
        %{required(:test) => float()}
      end
    end

    test "returns success with an integer value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: 31.2})
    end

    test "returns error with a non-integer value", %{contract: contract} do
      assert_errors(["test must be a float"], contract.conform(%{test: "Hello"}))
    end
  end

  describe "type?/2 with :map" do
    contract do
      schema do
        %{required(:test) => type(:map)}
      end
    end

    test "returns success with a map value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: %{}})
    end

    test "returns error with a non-map value", %{contract: contract} do
      assert_errors(["test must be a map"], contract.conform(%{test: 312}))
    end
  end

  describe "type?/2 with :date" do
    contract do
      schema do
        %{required(:test) => type(:date)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: ~D[2023-09-12]})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert_errors(["test must be a date"], contract.conform(%{test: 312}))
    end
  end

  describe "type?/2 with :date_time" do
    contract do
      schema do
        %{required(:test) => type(:date_time)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: DateTime.utc_now()})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert_errors(["test must be a date time"], contract.conform(%{test: 312}))
    end
  end

  describe "type?/2 with :time" do
    contract do
      schema do
        %{required(:test) => type(:time)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: Time.utc_now()})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert_errors(["test must be a time"], contract.conform(%{test: 312}))
    end
  end

  describe "type?/2 with :list" do
    contract do
      schema do
        %{required(:test) => type(:list)}
      end
    end

    test "returns success with a string value", %{contract: contract} do
      assert {:ok, _} = contract.conform(%{test: [1, 2, 3]})
    end

    test "returns error with a non-string value", %{contract: contract} do
      assert_errors(["test must be a list"], contract.conform(%{test: 312}))
    end
  end

  describe "filled?/1" do
    contract do
      schema do
        %{required(:test) => type(:string, [:filled?])}
      end
    end

    test "returns success with a non-empty string", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error with an empty string", %{contract: contract} do
      assert_errors(["test must be filled"], contract.conform(%{test: ""}))
    end
  end

  describe "empty?/1 with :string" do
    contract do
      schema do
        %{required(:test) => type(:string, [:empty?])}
      end
    end

    test "returns success with an empty string", %{contract: contract} do
      assert {:ok, %{test: ""}} = contract.conform(%{test: ""})
    end

    test "returns error with a non-empty string", %{contract: contract} do
      assert_errors(["test must be empty"], contract.conform(%{test: "Hello"}))
    end
  end

  describe "empty?/1 with :list" do
    contract do
      schema do
        %{required(:test) => type(:list, [:empty?])}
      end
    end

    test "returns success with an empty list", %{contract: contract} do
      assert {:ok, %{test: []}} = contract.conform(%{test: []})
    end

    test "returns error with a non-empty list", %{contract: contract} do
      assert_errors(["test must be empty"], contract.conform(%{test: [1, 2]}))
    end
  end

  describe "empty?/1 with :map" do
    contract do
      schema do
        %{required(:test) => type(:map, [:empty?])}
      end
    end

    test "returns success with an empty map", %{contract: contract} do
      assert {:ok, %{test: %{}}} = contract.conform(%{test: %{}})
    end

    test "returns error with a non-empty map", %{contract: contract} do
      assert_errors(["test must be empty"], contract.conform(%{test: %{a: 1}}))
    end
  end

  describe "eql?/1" do
    contract do
      schema do
        %{required(:test) => type(:string, eql?: "Hello")}
      end
    end

    test "returns success when the value is equal", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error when the value is not equal", %{contract: contract} do
      assert_errors(["test must be equal to Hello"], contract.conform(%{test: "World"}))
    end
  end

  describe "not_eql?/1" do
    contract do
      schema do
        %{required(:test) => type(:string, not_eql?: "Hello")}
      end
    end

    test "returns success when the value is not equal", %{contract: contract} do
      assert {:ok, %{test: "World"}} = contract.conform(%{test: "World"})
    end

    test "returns error when the value is equal", %{contract: contract} do
      assert_errors(
        ["test must not be equal to Hello"],
        contract.conform(%{test: "Hello"})
      )
    end
  end

  describe "even?/1" do
    contract do
      schema do
        %{required(:test) => type(:integer, [:even?])}
      end
    end

    test "returns success when the value is even", %{contract: contract} do
      assert {:ok, %{test: 12}} = contract.conform(%{test: 12})
    end

    test "returns error when the value is not even", %{contract: contract} do
      assert_errors(["test must be even"], contract.conform(%{test: 11}))
    end
  end

  describe "odd/1" do
    contract do
      schema do
        %{required(:test) => type(:integer, [:odd?])}
      end
    end

    test "returns success when the value is even", %{contract: contract} do
      assert {:ok, %{test: 11}} = contract.conform(%{test: 11})
    end

    test "returns error when the value is not even", %{contract: contract} do
      assert_errors(["test must be odd"], contract.conform(%{test: 12}))
    end
  end

  describe "gt?/1" do
    contract do
      schema do
        %{required(:test) => type(:integer, gt?: 1)}
      end
    end

    test "returns success when the value is greater than the arg", %{contract: contract} do
      assert {:ok, %{test: 11}} = contract.conform(%{test: 11})
    end

    test "returns error when the value is not greater than the arg", %{contract: contract} do
      assert_errors(["test must be greater than 1"], contract.conform(%{test: 0}))
    end
  end

  describe "gteq?/1" do
    contract do
      schema do
        %{required(:test) => type(:integer, gteq?: 1)}
      end
    end

    test "returns success when the value is greater than the arg", %{contract: contract} do
      assert {:ok, %{test: 2}} = contract.conform(%{test: 2})
    end

    test "returns success when the value is equal to the arg", %{contract: contract} do
      assert {:ok, %{test: 1}} = contract.conform(%{test: 1})
    end

    test "returns error when the value less than the arg", %{contract: contract} do
      assert_errors(
        ["test must be greater than or equal to 1"],
        contract.conform(%{test: 0})
      )
    end
  end

  describe "lt?/1" do
    contract do
      schema do
        %{required(:test) => type(:integer, lt?: 1)}
      end
    end

    test "returns success when the value is less than the arg", %{contract: contract} do
      assert {:ok, %{test: 0}} = contract.conform(%{test: 0})
    end

    test "returns error when the value is not even", %{contract: contract} do
      assert_errors(["test must be less than 1"], contract.conform(%{test: 2}))
    end
  end

  describe "lteq?/1" do
    contract do
      schema do
        %{required(:test) => type(:integer, lteq?: 1)}
      end
    end

    test "returns success when the value is less than the arg", %{contract: contract} do
      assert {:ok, %{test: 0}} = contract.conform(%{test: 0})
    end

    test "returns success when the value is equal to the arg", %{contract: contract} do
      assert {:ok, %{test: 1}} = contract.conform(%{test: 1})
    end

    test "returns error when the value greater than the arg", %{contract: contract} do
      assert_errors(
        ["test must be less than or equal to 1"],
        contract.conform(%{test: 2})
      )
    end
  end

  describe "size?/1 with a list" do
    contract do
      schema do
        %{required(:test) => type(:list, size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: [1, 2]}} = contract.conform(%{test: [1, 2]})
    end

    test "returns error when the value's size is not equal to the arg", %{
      contract: contract
    } do
      assert_errors(["test size must be 2"], contract.conform(%{test: [1]}))
    end
  end

  describe "size?/1 with a map" do
    contract do
      schema do
        %{required(:test) => type(:map, size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: %{a: 1, b: 2}}} =
               contract.conform(%{test: %{a: 1, b: 2}})
    end

    test "returns error when the value's size is not equal to the arg", %{
      contract: contract
    } do
      assert_errors(["test size must be 2"], contract.conform(%{test: %{a: 1}}))
    end
  end

  describe "size?/1 with a string" do
    contract do
      schema do
        %{required(:test) => type(:string, size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: "ab"}} = contract.conform(%{test: "ab"})
    end

    test "returns error when the value's size is not equal to the arg", %{
      contract: contract
    } do
      assert_errors(["test size must be 2"], contract.conform(%{test: "a"}))
    end
  end

  describe "max_size?/1 with a list" do
    contract do
      schema do
        %{required(:test) => type(:list, max_size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: [1, 2]}} = contract.conform(%{test: [1, 2]})
    end

    test "returns success when the value's size is less than the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: [1]}} = contract.conform(%{test: [1]})
    end

    test "returns error when the value's size is greater than the arg", %{
      contract: contract
    } do
      assert_errors(
        ["test size cannot be greater than 2"],
        contract.conform(%{test: [1, 2, 3]})
      )
    end
  end

  describe "max_size?/1 with a string" do
    contract do
      schema do
        %{required(:test) => string(max_size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: "ab"}} = contract.conform(%{test: "ab"})
    end

    test "returns success when the value's size is less than the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: "a"}} = contract.conform(%{test: "a"})
    end

    test "returns error when the value's size is greater than the arg", %{
      contract: contract
    } do
      assert_errors(
        ["test size cannot be greater than 2"],
        contract.conform(%{test: "abc"})
      )
    end
  end

  describe "max_size/1 with a map" do
    contract do
      schema do
        %{required(:test) => map(max_size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: %{a: 1, b: 2}}} =
               contract.conform(%{test: %{a: 1, b: 2}})
    end

    test "returns success when the value's size is less than the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: %{a: 1}}} = contract.conform(%{test: %{a: 1}})
    end

    test "returns error when the value's size is greater than the arg", %{
      contract: contract
    } do
      assert_errors(
        ["test size cannot be greater than 2"],
        contract.conform(%{test: %{a: 1, b: 2, c: 3}})
      )
    end
  end

  describe "min_size?/1 with a list" do
    contract do
      schema do
        %{required(:test) => type(:list, min_size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: [1, 2]}} = contract.conform(%{test: [1, 2]})
    end

    test "returns success when the value's size is greater than the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: [1, 2, 3]}} = contract.conform(%{test: [1, 2, 3]})
    end

    test "returns error when the value's size is less than the arg", %{
      contract: contract
    } do
      assert_errors(["test size cannot be less than 2"], contract.conform(%{test: [1]}))
    end
  end

  describe "min_size?/1 with a string" do
    contract do
      schema do
        %{required(:test) => string(min_size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: "ab"}} = contract.conform(%{test: "ab"})
    end

    test "returns success when the value's size is greater than the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: "abc"}} = contract.conform(%{test: "abc"})
    end

    test "returns error when the value's size is less than the arg", %{
      contract: contract
    } do
      assert_errors(["test size cannot be less than 2"], contract.conform(%{test: "a"}))
    end
  end

  describe "min_size?/1 with a map" do
    contract do
      schema do
        %{required(:test) => map(min_size?: 2)}
      end
    end

    test "returns success when the value's size is equal to the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: %{a: 1, b: 2}}} =
               contract.conform(%{test: %{a: 1, b: 2}})
    end

    test "returns success when the value's size is greater than the arg", %{
      contract: contract
    } do
      assert {:ok, %{test: %{a: 1, b: 2, c: 3}}} =
               contract.conform(%{test: %{a: 1, b: 2, c: 3}})
    end

    test "returns error when the value's size is less than the arg", %{
      contract: contract
    } do
      assert_errors(
        ["test size cannot be less than 2"],
        contract.conform(%{test: %{a: 1}})
      )
    end
  end

  describe "includes?/2 with a list" do
    contract do
      schema do
        %{required(:test) => type(:list, includes?: 2)}
      end
    end

    test "returns success when the arg is included in the list", %{contract: contract} do
      assert {:ok, %{test: [1, 2]}} = contract.conform(%{test: [1, 2]})
    end

    test "returns success when the arg is not included in the list", %{contract: contract} do
      assert_errors(["test must include 2"], contract.conform(%{test: [1, 3]}))
    end
  end

  describe "excludes?/2 with a list" do
    contract do
      schema do
        %{required(:test) => type(:list, excludes?: 2)}
      end
    end

    test "returns success when the arg is not included in the list", %{contract: contract} do
      assert {:ok, %{test: [1, 3]}} = contract.conform(%{test: [1, 3]})
    end

    test "returns success when the arg is included in the list", %{contract: contract} do
      assert_errors(["test must exclude 2"], contract.conform(%{test: [1, 2]}))
    end
  end

  describe "match?/2" do
    contract do
      schema do
        %{required(:test) => type(:string, match?: ~r/\d+/)}
      end
    end

    test "returns success when the value matches the regexp", %{contract: contract} do
      assert {:ok, %{test: "312"}} = contract.conform(%{test: "312"})
    end

    test "returns success when the value doesn't match the regexp", %{contract: contract} do
      assert_errors(["test must have a valid format"], contract.conform(%{test: "Hello"}))
    end
  end

  describe "in?/2 with a single value" do
    contract do
      schema do
        %{required(:test) => type(:string, in?: ["Hello"])}
      end
    end

    test "returns success when the value is in the list", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error when the value is not in the list", %{contract: contract} do
      assert_errors(
        ["test must be one of: Hello"],
        contract.conform(%{test: "312"})
      )
    end
  end

  describe "in?/2 with multiple values" do
    contract do
      schema do
        %{required(:test) => type(:string, in?: ["Hello", "World"])}
      end
    end

    test "returns success when the value is in the list", %{contract: contract} do
      assert {:ok, %{test: "Hello"}} = contract.conform(%{test: "Hello"})
    end

    test "returns error when the value is not in the list", %{contract: contract} do
      assert_errors(
        ["test must be one of: Hello, World"],
        contract.conform(%{test: "312"})
      )
    end
  end

  describe "not_in?/2 with a single value" do
    contract do
      schema do
        %{required(:test) => type(:string, not_in?: ["Hello"])}
      end
    end

    test "returns success when the value is not in the list", %{contract: contract} do
      assert {:ok, %{test: "312"}} = contract.conform(%{test: "312"})
    end

    test "returns error when the value is in the list", %{contract: contract} do
      assert_errors(
        ["test must not be one of: Hello"],
        contract.conform(%{test: "Hello"})
      )
    end
  end

  describe "not_in?/2 with multiple values" do
    contract do
      schema do
        %{required(:test) => type(:string, not_in?: ["Hello", "World"])}
      end
    end

    test "returns success when the value is not in the list", %{contract: contract} do
      assert {:ok, %{test: "312"}} = contract.conform(%{test: "312"})
    end

    test "returns error when the value is in the list", %{contract: contract} do
      assert_errors(
        ["test must not be one of: Hello, World"],
        contract.conform(%{test: "Hello"})
      )
    end
  end
end
