defmodule Drops.CoercionTest do
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
end
