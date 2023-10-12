defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:count) => cast(:string) |> integer(gt?: 0)
    }
  end
end

UserContract.conform(%{count: "1"})
# {:ok, %{count: 1}}

UserContract.conform(%{count: "-1"})
# {:error, [error: {[:count], :gt?, [0, -1]}]}
