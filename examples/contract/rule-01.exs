defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:email) => maybe(:string),
      required(:login) => maybe(:string)
    }
  end

  rule(:either_login_or_email, %{email: email, login: login}) do
    if email == nil and login == nil do
      {:error, "email or login must be present"}
    else
      :ok
    end
  end
end

UserContract.conform(%{email: "jane@doe.org", login: nil})

UserContract.conform(%{email: nil, login: "jane"})

UserContract.conform(%{email: nil, login: nil})
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Rule{
#      path: [],
#      text: "email or login must be present",
#      meta: %{}
#    }
#  ]}
