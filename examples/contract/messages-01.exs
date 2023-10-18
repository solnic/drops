defmodule MyBackend do
  use Drops.Contract.Messages.Backend

  def text(:type?, type, input) do
    "#{inspect(input)} received but it must be a #{type}"
  end

  def text(:filled?, _input) do
    "cannot be empty"
  end
end
defmodule UserContract do
  use Drops.Contract, message_backend: MyBackend

  schema do
    %{
      required(:name) => string(:filled?),
      required(:email) => string(:filled?)
    }
  end
end
UserContract.conform(%{name: "", email: 312}) |> UserContract.errors()
