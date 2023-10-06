defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => type(:string),
      required(:age) => type(:integer)
    }
  end
end

UserContract.conform(%{name: "John", age: 21})
