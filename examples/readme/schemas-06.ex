defmodule CustomCaster do
  def cast(:string, :string, value, _opts) do
    String.downcase(value)
  end
end

defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:text) => cast(:string, caster: CustomCaster) |> string()
    }
  end
end

UserContract.conform(%{text: "HELLO"})
# {:ok, %{text: "hello"}}
