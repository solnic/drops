defmodule Types.Price do
  use Drops.Type, union([:integer, :float], gt?: 0)
end

defmodule ProductContract do
  use Drops.Contract

  schema do
    %{
      required(:price) => Types.Price
    }
  end
end

ProductContract.conform(%{price: 42})
# {:ok, %{price: 42}}

ProductContract.conform(%{price: 42.3})
# {:ok, %{price: 42.3}}

{:error, errors} = ProductContract.conform(%{price: -42})
Enum.map(errors, &to_string/1)
# ["price must be greater than 0"]

{:error, errors} = ProductContract.conform(%{price: "42"})
Enum.map(errors, &to_string/1)
# ["price must be an integer or price must be a float"]
