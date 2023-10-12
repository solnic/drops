defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      optional(:name) => string(),
      required(:email) => string()
    }
  end
end

UserContract.conform(%{email: "janedoe.org"})
# {:ok, %{email: "janedoe.org"}}

UserContract.conform(%{name: "Jane", email: "janedoe.org"})
# {:ok, %{name: "Jane", email: "janedoe.org"}}
