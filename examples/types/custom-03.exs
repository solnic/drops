defmodule User do
  use Drops.Type, %{
    required(:name) => string(),
    required(:email) => string()
  }
end
defmodule AccountContract do
  use Drops.Contract

  schema do
    %{
      required(:user) => User
    }
  end
end
AccountContract.conform(%{user: %{name: "Jane", email: "janedoe.org"}})
{:error, errors} = AccountContract.conform(%{user: %{name: "Jane", email: 1}})
Enum.map(errors, &to_string/1)
