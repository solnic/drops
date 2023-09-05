defmodule DropsTest do
  use ExUnit.Case

  describe "schema" do
    test "defining a required key" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          required(:name, :string)
          required(:age, :integer)
        end
      end

      assert [{:ok, "Jane"}, {:error, {:has_key?, :age}}] =
               TestContract.apply(%{name: "Jane"})

      assert [{:ok, "Jane"}, {:ok, 21}] = TestContract.apply(%{name: "Jane", age: 21})

      assert [{:error, {:string?, 312}}, {:ok, 21}] =
               TestContract.apply(%{name: 312, age: 21})
    end
  end
end
