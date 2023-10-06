defmodule UserContract do
  use Drops.Contract

  schema(atomize: true) do
    %{
      required(:user) => %{
        required(:name) => type(:string, [:filled?]),
        required(:age) => type(:integer),
        required(:address) => %{
          required(:city) => type(:string, [:filled?]),
          required(:street) => type(:string, [:filled?]),
          required(:zipcode) => type(:string, [:filled?])
        }
      }
    }
  end
end

# UserContract.conform(%{
#  "user" => %{
#    "name" => "John",
#    "age" => 21,
#    "address" => %{
#      "city" => "New York",
#      "street" => "",
#      "zipcode" => "10001"
#    }
#  }
# })

UserContract.conform(%{
 "user" => %{
   "name" => "John",
   "age" => 21,
   "address" => %{
     "city" => "New York",
     "street" => "Central Park",
     "zipcode" => "10001"
   }
 }
})
