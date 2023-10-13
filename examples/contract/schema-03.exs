defmodule UserContract do
  use Drops.Contract

  schema(:address) do
    %{
      required(:street) => string(:filled?),
      required(:city) => string(:filled?),
      required(:zip) => string(:filled?),
      required(:country) => string(:filled?)
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

UserContract.conform(%{
  name: "John",
  age: 21,
  address: %{
    street: "Main St.",
    city: "New York",
    zip: "10001",
    country: "USA"
  }
})

UserContract.conform(%{
  name: "John",
  age: "21",
  address: %{
    street: "Main St.",
    city: "",
    zip: "10001",
    country: "USA"
  }
})
