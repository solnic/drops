defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => string(),
      required(:email) => string()
    }
  end
end

UserContract.conform(%{name: "Jane", email: "jane@doe.org"})
UserContract.conform(%{email: 312})
UserContract.conform(%{name: "Jane", email: 312})
