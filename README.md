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

## Contracts

You can use `Drops.Contract` to define data coercion and validation schemas with arbitrary validation rules. Here's an example of a `UserContract` which casts and validates a nested map:

```elixir
defmodule UserContract do
  use Drops.Contract

  schema(atomize: true) do
    %{
      required(:user) => %{
        required(:name) => string(:filled?),
        required(:age) => integer(),
        required(:address) => %{
          required(:city) => string(:filled?),
          required(:street) => string(:filled?),
          required(:zipcode) => string(:filled?)
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

## Rules

You can define arbitrary rule functions using `rule` macro. These rules will be applied to the input data only if it passed schema validation. This way you can be sure that rules operate on data that's safe to work with.


Here's an example how you could define a rule that checks if either email or login is provided:


```elixir
defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:email) => maybe(:string),
      required(:login) => maybe(:string)
    }
  end

  rule(:either_login_or_email, %{email: nil, login: nil}) do
    {:error, "email or login must be provided"}
  end
end

UserContract.conform(%{email: "jane@doe.org", login: nil})
# {:ok, %{email: "jane@doe.org", login: nil}}

UserContract.conform(%{email: nil, login: "jane"})
# {:ok, %{email: nil, login: "jane"}}

UserContract.conform(%{email: nil, login: nil})
# {:error, [error: "email or login must be provided"]}
```
