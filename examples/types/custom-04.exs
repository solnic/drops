defmodule Price do
  use Drops.Type, union([:integer, :float], gt?: 0)
end
defmodule ProductContract do
  use Drops.Contract

  schema do
    %{
      required(:unit_price) => Price
    }
  end
end
ProductContract.conform(%{unit_price: 1})
{:ok, %{unit_price: 1}}
ProductContract.conform(%{unit_price: 1.5})
{:ok, %{unit_price: 1.5}}
{:error, errors} = ProductContract.conform(%{unit_price: -1})
Enum.map(errors, &to_string/1)
