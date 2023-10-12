defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => string(:filled?),
      required(:age) => integer(gt?: 18)
    }
  end
end

UserContract.conform(%{name: "Jane", age: 21})
# {:ok, %{name: "Jane", age: 21}}

UserContract.conform(%{name: "", age: 21})
# {:error, [error: {[:name], :filled?, [""]}]}

UserContract.conform(%{name: "Jane", age: 12})
# {:error, [error: {[:age], :gt?, [18, 12]}]}
