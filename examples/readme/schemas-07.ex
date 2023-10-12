defmodule UserContract do
  use Drops.Contract

  schema(atomize: true) do
    %{
      required(:name) => string(),
      required(:age) => integer(),
      required(:tags) =>
        list(%{
          required(:name) => string()
        })
    }
  end
end

UserContract.conform(%{
  "name" => "Jane",
  "age" => 21,
  "tags" => [
    %{"name" => "red"},
    %{"name" => "green"},
    %{"name" => "blue"}
  ]
})
# {:ok,
#  %{
#    name: "Jane",
#    age: 21,
#    tags: [%{name: "red"}, %{name: "green"}, %{name: "blue"}]
#  }}
