defmodule Drops.CastersTest do
  use Drops.ContractCase

  describe ":integer => :string" do
    contract do
      schema do
        %{required(:test) => from(:integer) |> type(:string)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{test: "12"}} = contract.conform(%{test: 12})
    end
  end

  describe ":string => :integer" do
    contract do
      schema do
        %{required(:test) => from(:string) |> type(:integer)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{test: 12}} = contract.conform(%{test: "12"})
    end
  end

  describe ":string => :float" do
    contract do
      schema do
        %{required(:test) => from(:string) |> type(:float)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{test: 31.2}} = contract.conform(%{test: "31.2"})
    end
  end

  describe ":integer => :date_time" do
    contract do
      schema do
        %{required(:test) => from(:integer) |> type(:date_time)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      timestamp = 1695277470
      date_time = DateTime.from_unix!(timestamp, :second)

      assert {:ok, %{test: ^date_time}} = contract.conform(%{test: timestamp})
    end
  end

  describe ":integer => :date_time with :milliseconds" do
    contract do
      schema do
        %{required(:test) => from(:integer, [:millisecond]) |> type(:date_time)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      timestamp = 1695277723355
      date_time = DateTime.from_unix!(timestamp, :millisecond)

      assert {:ok, %{test: ^date_time}} = contract.conform(%{test: timestamp})
    end
  end

  describe "using a customer caster" do
    contract do
      defmodule CustomCaster do
        def cast(:string, :string, value, _opts) do
          String.downcase(value)
        end
      end

      schema do
        %{required(:test) => from(:string, caster: CustomCaster) |> type(:string)}
      end
    end

    test "defining a required key with coercion", %{contract: contract} do
      assert {:ok, %{test: "hello"}} = contract.conform(%{test: "HELLO"})
    end
  end
end
