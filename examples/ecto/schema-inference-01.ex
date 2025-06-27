defmodule UserSchema do
  use Ecto.Schema

  schema "users" do
    field(:name, :string)
    field(:email, :string)
    field(:age, :integer)

    timestamps()
  end
end

defmodule UserContract do
  use Drops.Contract

  schema(UserSchema)
end

UserContract.conform(%{name: "Jane", email: "jane@doe.org", age: 21})
# {:ok, %{age: 21, email: "jane@doe.org", name: "Jane"}}

UserContract.conform(%{name: "Jane", email: "jane@doe.org", age: "21"})
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Type{
#      path: [:age],
#      text: "must be an integer",
#      meta: [predicate: :type?, args: [:integer, "21"]]
#    }
#  ]}
