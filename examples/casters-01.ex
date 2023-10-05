defmodule UserContract do
  use Drops.Contract

  schema do
    %{required(:age) => cast(:string) |> type(:integer)}
  end
end

UserContract.conform(%{age: "20"})
