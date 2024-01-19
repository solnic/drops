defmodule Drops.ValidatorTest do
  use Drops.ContractCase
  use Drops.Validator

  describe "validate/3" do
    test "validates a string" do
      assert validate("foo", Types.Primitive.new(:string), path: []) ==
               {:ok, {[], "foo"}}
    end

    test "validates an integer with constraints" do
      type = Types.Primitive.new(:integer, [:odd?])

      assert validate(11, type, path: []) == {:ok, {[], 11}}

      assert validate("foo", type, path: []) == {:error, {[], :type?, [:integer, "foo"]}}
      assert validate(12, type, path: []) == {:error, {[], :odd?, [12]}}
    end
  end
end
