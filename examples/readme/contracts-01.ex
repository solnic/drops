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
# {:ok, %{name: "Jane", email: "jane@doe.org"}}

UserContract.conform(%{email: 312})
# {:error, [error: {[], :has_key?, [:name]}]}

UserContract.conform(%{name: "Jane", email: 312})
# {:error, [error: {[:email], :type?, [:string, 312]}]}
