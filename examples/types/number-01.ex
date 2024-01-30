defmodule ProductContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => string(:filled?),
      required(:price) => number()
    }
  end
end

ProductContract.conform(%{name: "Book", price: 31.2})

ProductContract.conform(%{name: "Book", price: 31})

{:error, errors} = ProductContract.conform(%{name: "Book", price: []})
Enum.map(errors, &to_string/1)
