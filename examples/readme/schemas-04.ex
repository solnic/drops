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
#    %Drops.Contract.Messages.Error.Type{
#      path: [:user, :address, :zipcode],
#      text: "must be filled",
#      meta: %{args: [""], predicate: :filled?}
#    },
#    %Drops.Contract.Messages.Error.Type{
#      path: [:user, :tags, 1, :created_at],
#      text: "must be an integer",
#      meta: %{args: [:integer, nil], predicate: :type?}
#    }
#  ]}
