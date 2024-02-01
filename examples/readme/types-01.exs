defmodule Types.Age do
  use Drops.Type, integer(gteq?: 0)
end

defmodule Types.Name do
  use Drops.Type, string(:filled?)
end

defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => Types.Name,
      required(:age) => Types.Age
    }
  end
end

UserContract.conform(%{name: "Jane", age: 42})
# {:ok, %{name: "Jane", age: 42}}

{:error, errors} = UserContract.conform(%{name: "Jane", age: -42})
Enum.map(errors, &to_string/1)
# ["age must be greater than or equal to 0"]

{:error, errors} = UserContract.conform(%{name: "Jane", age: "42"})
Enum.map(errors, &to_string/1)
# ["age must be an integer"]
