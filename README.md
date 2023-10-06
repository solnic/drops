# Drops

Elixir `Drops` is a collection of small modules that provide useful extensions and functions that can be used to work with data effectively.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed by adding `drops` to your list of dependencies in `mix.exs`:

```elixir
def deps do
  [
    {:drops, "~> 0.1.0"}
  ]
end
```

Documentation can be generated with [ExDoc](https://github.com/elixir-lang/ex_doc) and published on [HexDocs](https://hexdocs.pm). Once published, the docs can be found at <https://hexdocs.pm/drops>.

## Drops.Contract

You can use Drops.Contract to define data coercion and validation schemas with arbitrary validation rules. Here's a simple example:

```elixir
defmodule UserContract do
  use Drops.Contract

  schema(atomize: true) do
    %{
      required(:user) => %{
        required(:name) => type(:string, [:filled?]),
        required(:age) => type(:integer),
        required(:address) => %{
          required(:city) => type(:string, [:filled?]),
          required(:street) => type(:string, [:filled?]),
          required(:zipcode) => type(:string, [:filled?])
        }
      }
    }
  end
end

UserContract.conform(%{
 "user" => %{
   "name" => "John",
   "age" => 21,
   "address" => %{
     "city" => "New York",
     "street" => "",
     "zipcode" => "10001"
   }
 }
})
# {:error, [error: {:filled?, [:user, :address, :street], ""}]}

UserContract.conform(%{
 "user" => %{
   "name" => "John",
   "age" => 21,
   "address" => %{
     "city" => "New York",
     "street" => "Central Park",
     "zipcode" => "10001"
   }
 }
})
# {:ok,
#  %{
#    user: %{
#      name: "John",
#      address: %{city: "New York", street: "Central Park", zipcode: "10001"},
#      age: 21
#    }
#  }}
```

