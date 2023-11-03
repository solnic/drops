defmodule FilledString do
  use Drops.Type, {:string, [:filled?]}
end

defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => FilledString
    }
  end
end

UserContract.conform(%{name: "Jane Doe"})
# {:ok, %{name: "Jane Doe"}}

{:error, errors} = UserContract.conform(%{name: 1})
Enum.map(errors, &to_string/1)
# ["name must be a string"]

{:error, errors} = UserContract.conform(%{name: ""})
Enum.map(errors, &to_string/1)
# ["name must be filled"]

[%{type: type}]= UserContract.schema().keys
# %FilledString{
#   primitive: :string,
#   constraints: {:and, [predicate: {:type?, :string}, predicate: {:filled?, []}]}
# }
