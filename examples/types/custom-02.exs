defmodule Email do
  use Drops.Type, string(:filled?)
end
defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:email) => Email
    }
  end
end
UserContract.conform(%{email: "jane@doe.org"})
{:error, errors} = UserContract.conform(%{email: ""})
Enum.map(errors, &to_string/1)
[%{type: type}]= UserContract.schema().keys
type
