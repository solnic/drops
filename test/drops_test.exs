defmodule DropsTest do
  use ExUnit.Case

  describe "schema" do
    test "defining required keys with types" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          required(:name, :string)
          required(:age, :integer)
        end
      end

      assert [{:error, {:has_key?, :age}}] = TestContract.apply(%{name: "Jane"})

      assert %{name: "Jane", age: 21} = TestContract.apply(%{name: "Jane", age: 21})

      assert [{:error, {:string?, 312}}] = TestContract.apply(%{name: 312, age: 21})

      assert [{:error, {:string?, 312}}, {:error, {:integer?, "21"}}] =
               TestContract.apply(%{name: 312, age: "21"})
    end
  end
end
