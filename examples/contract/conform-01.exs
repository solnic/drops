defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => type(:string),
      required(:age) => type(:integer)
    }
  end
end

UserContract.conform(%{name: "Jane", age: 48})

UserContract.conform(%{name: "Jane", age: "not an integer"})
