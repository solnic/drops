defmodule Drops.Contract.SchemaTest do
  use Drops.ContractCase

  describe "schema/1 with name" do
    contract do
      schema(:address) do
        %{
          required(:street) => string(),
          required(:city) => string(),
          required(:zip) => string(),
          required(:country) => string()
        }
      end

      schema do
        %{
          required(:name) => string(),
          required(:age) => integer(),
          required(:address) => @schemas.address
        }
      end
    end

    test "defines a named schema", %{contract: contract} do
      assert {:ok,
              %{
                name: "John",
                age: 21,
                address: %{
                  street: "Main St.",
                  city: "New York",
                  zip: "10001",
                  country: "USA"
                }
              }} =
               contract.conform(%{
                 name: "John",
                 age: 21,
                 address: %{
                   street: "Main St.",
                   city: "New York",
                   zip: "10001",
                   country: "USA"
                 }
               })
    end
  end

  describe "schema/1 with name and options" do
    contract do
      schema(:address, atomize: true) do
        %{
          required(:street) => string(),
          required(:city) => string(),
          required(:zip) => string(),
          required(:country) => string()
        }
      end

      schema(atomize: true) do
        %{
          required(:name) => string(),
          required(:age) => integer(),
          required(:address) => @schemas.address
        }
      end
    end

    test "defines a named schema", %{contract: contract} do
      assert {:ok,
              %{
                name: "John",
                age: 21,
                address: %{
                  street: "Main St.",
                  city: "New York",
                  zip: "10001",
                  country: "USA"
                }
              }} =
               contract.conform(%{
                 "name" => "John",
                 "age" => 21,
                 "address" => %{
                   "street" => "Main St.",
                   "city" => "New York",
                   "zip" => "10001",
                   "country" => "USA"
                 }
               })
    end
  end
end
