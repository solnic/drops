defmodule Types.User do
  use Drops.Type, %{
    required(:name) => string(:filled?),
    required(:age) => integer(gteq?: 0)
  }
end

defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:user) => Types.User
    }
  end
end

UserContract.conform(%{user: %{name: "Jane", age: 42}})
# {:ok, %{user: %{name: "Jane", age: 42}}}

{:error, errors} = UserContract.conform(%{user: %{name: "Jane", age: -42}})
Enum.map(errors, &to_string/1)
# ["user.age must be greater than or equal to 0"]

{:error, errors} = UserContract.conform(%{user: %{name: "Jane", age: "42"}})
Enum.map(errors, &to_string/1)
# ["user.age must be an integer"]
