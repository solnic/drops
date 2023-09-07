defmodule DropsTest do
  use ExUnit.Case

  describe "schema" do
    setup(_) do
      on_exit(fn ->
        :code.purge DropsTest.TestContract
        :code.delete DropsTest.TestContract
      end)
    end

    test "defining required keys with types" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          %{
            required(:name) => type(:string),
            required(:age) => type(:integer)
          }
        end
      end

      assert [{:error, {:has_key?, :age}}] = TestContract.apply(%{name: "Jane"})

      assert %{name: "Jane", age: 21} = TestContract.apply(%{name: "Jane", age: 21})

      assert [{:error, {:string?, :name, 312}}] =
               TestContract.apply(%{name: 312, age: 21})

      result = TestContract.apply(%{name: 312, age: "21"})

      assert Enum.member?(result, {:error, {:string?, :name, 312}})
      assert Enum.member?(result, {:error, {:integer?, :age, "21"}})
    end

    test "defining required keys with types and extra predicates" do
      defmodule TestContract do
        use Drops.Contract

        schema do
          %{
            required(:name) => type(:string, [:filled?]),
            required(:age) => type(:integer)
          }
        end
      end

      assert [{:error, {:filled?, :name, ""}}] = TestContract.apply(%{name: "", age: 21})
    end
  end
end
