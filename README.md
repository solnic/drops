# Elixir Drops 💦
[![Elixir CI](https://github.com/solnic/drops/actions/workflows/elixir.yml/badge.svg)](https://github.com/solnic/drops/actions/workflows/elixir.yml) [![Hex pm](https://img.shields.io/hexpm/v/drops.svg?style=flat)](https://hex.pm/packages/drops) [![hex.pm downloads](https://img.shields.io/hexpm/dt/drops.svg?style=flat)](https://hex.pm/packages/drops)

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

You can use `Drops.Contract` to define data coercion and validation schemas with arbitrary validation rules.

Here's an example of a simple `UserContract` which defines two required keys and expected types:

```elixir
defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => string(),
      required(:email) => string()
    }
  end
end

UserContract.conform(%{name: "Jane", email: "jane@doe.org"})
# {:ok, %{name: "Jane", email: "jane@doe.org"}}

{:error, errors} = UserContract.conform(%{email: 312})
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Type{
#      path: [:email],
#      text: "must be a string",
#      meta: %{args: [:string, 312], predicate: :type?}
#    },
#    %Drops.Validator.Messages.Error.Key{
#      path: [:name],
#      text: "key must be present",
#      meta: %{args: [:name], predicate: :has_key?}
#    }
#  ]}

Enum.map(errors, &to_string/1)
# ["email must be a string", "name key must be present"]

{:error, errors} = UserContract.conform(%{name: "Jane", email: 312})
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Type{
#      path: [:email],
#      text: "must be a string",
#      meta: %{args: [:string, 312], predicate: :type?}
#    }
#  ]}

Enum.map(errors, &to_string/1)
# ["email must be a string"]
```

## Schemas

Contract's schemas are a powerful way of defining the exact shape of the data you expect to work with. They are used to validate **the structure** and **the values** of the input data. Using schemas, you can define which keys are required and whic are optional, the exact types of the values and any additional checks that have to be applied to the values.

### Required and optional keys

A schema must explicitly define which keys are required and which are optional. This is done by using `required` and `optional` functions. Here's an example:

```elixir
defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      optional(:name) => string(),
      required(:email) => string()
    }
  end
end

UserContract.conform(%{email: "janedoe.org"})
# {:ok, %{email: "janedoe.org"}}

UserContract.conform(%{name: "Jane", email: "janedoe.org"})
# {:ok, %{name: "Jane", email: "janedoe.org"}}
```

### Types

You can define the expected types of the values using `string`, `integer`, `float`, `boolean`, `atom`, `map`, `list`, `any` and `maybe` functions. Here's an example:

```elixir
defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => string(),
      required(:age) => integer(),
      required(:active) => boolean(),
      required(:tags) => list(:string),
      required(:settings) => map(:string),
      required(:address) => maybe(:string)
    }
  end
end
```

### Predicate checks

You can define types that must meet additional requirements by using built-in predicates. Here's an example:

```elixir
defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:name) => string(:filled?),
      required(:age) => integer(gt?: 18)
    }
  end
end

UserContract.conform(%{name: "Jane", age: 21})
# {:ok, %{name: "Jane", age: 21}}

UserContract.conform(%{name: "", age: 21})
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Type{
#      path: [:name],
#      text: "must be filled",
#      meta: %{args: [""], predicate: :filled?}
#    }
#  ]}

UserContract.conform(%{name: "Jane", age: 12})
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Type{
#      path: [:age],
#      text: "must be greater than 18",
#      meta: %{args: [18, 12], predicate: :gt?}
#    }
#  ]}

```

### Nested schemas

Schemas can be nested, including complex cases like nested lists and maps. Here's an example:

```elixir
defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:user) => %{
        required(:name) => string(:filled?),
        required(:age) => integer(),
        required(:address) => %{
          required(:city) => string(:filled?),
          required(:street) => string(:filled?),
          required(:zipcode) => string(:filled?)
        },
        required(:tags) =>
          list(%{
            required(:name) => string(:filled?),
            required(:created_at) => integer()
          })
      }
    }
  end
end

UserContract.conform(%{
  user: %{
    name: "Jane",
    age: 21,
    address: %{
      city: "New York",
      street: "Broadway",
      zipcode: "10001"
    },
    tags: [
      %{name: "foo", created_at: 1_234_567_890},
      %{name: "bar", created_at: 1_234_567_890}
    ]
  }
})
# {:ok,
#   %{
#     user: %{
#       name: "Jane",
#       address: %{city: "New York", street: "Broadway", zipcode: "10001"},
#       age: 21,
#       tags: [
#         %{name: "foo", created_at: 1234567890},
#         %{name: "bar", created_at: 1234567890}
#       ]
#     }
#   }}

UserContract.conform(%{
  user: %{
    name: "Jane",
    age: 21,
    address: %{
      city: "New York",
      street: "Broadway",
      zipcode: ""
    },
    tags: [
      %{name: "foo", created_at: 1_234_567_890},
      %{name: "bar", created_at: nil}
    ]
  }
})
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Type{
#      path: [:user, :address, :zipcode],
#      text: "must be filled",
#      meta: %{args: [""], predicate: :filled?}
#    },
#    %Drops.Validator.Messages.Error.Type{
#      path: [:user, :tags, 1, :created_at],
#      text: "must be an integer",
#      meta: %{args: [:integer, nil], predicate: :type?}
#    }
#  ]}
```

### Type-safe casting

You can define custom type casting functions that will be applied to the input data before it's validated. This is useful when you want to convert the input data to a different format, for example, when you want to convert a string to an integer. Here's an example:

```elixir
defmodule UserContract do
  use Drops.Contract

  schema do
    %{
      required(:count) => cast(:string) |> integer(gt?: 0)
    }
  end
end

UserContract.conform(%{count: "1"})
# {:ok, %{count: 1}}

UserContract.conform(%{count: nil})
#  [
#    %Drops.Validator.Messages.Error.Caster{
#      error: %Drops.Validator.Messages.Error.Type{
#        path: [:count],
#        text: "must be a string",
#        meta: %{args: [:string, nil], predicate: :type?}
#      }
#    }
#  ]}

UserContract.conform(%{count: "-1"})
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Type{
#      path: [:count],
#      text: "must be greater than 0",
#      meta: %{args: [0, -1], predicate: :gt?}
#    }
#  ]}

```

It's also possible to define a custom casting module and use it via `caster` option:

```elixir
defmodule CustomCaster do
  @spec cast(input_type :: atom(), output_type :: atom(), any, Keyword.t()) :: any()
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
```

### Atomized maps

You can define a schema that will atomize the input map using `atomize: true` option. Only keys that you specified will be atomized, any unexpected key will be ignored. Here's an example:

```elixir
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
  "unexpected" => "value",
  "this" => "should not be here",
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
# {:error,
#  [
#    %Drops.Validator.Messages.Error.Rule{
#      path: [],
#      text: "email or login must be present",
#      meta: %{}
#    }
#  ]}
```
