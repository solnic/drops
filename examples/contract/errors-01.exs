defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => string(:filled?),
      required(:email) => string(:filled?)
    }
  end
end

errors = UserContract.conform(%{name: "", email: 312}) |> UserContract.errors()

Enum.map(errors, &to_string/1)
