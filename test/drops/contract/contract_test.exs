defmodule Drops.ContractTest do
  use Drops.ContractCase
  use Drops.DoctestCase

  doctest Drops.Contract

  describe "conform/1" do
    contract do
      schema do
        %{
          required(:name) => string(:filled?),
          required(:email) => string(:filled?)
        }
      end
    end

    test "returns errors when the input is not a map", %{contract: contract} do
      assert_errors(["must be a map"], contract.conform("not a map"))
    end
  end
end
