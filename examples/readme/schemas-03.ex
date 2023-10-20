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
#    %Drops.Contract.Messages.Error.Type{
#      path: [:name],
#      text: "must be filled",
#      meta: %{args: [""], predicate: :filled?}
#    }
#  ]}

UserContract.conform(%{name: "Jane", age: 12})
# {:error,
#  [
#    %Drops.Contract.Messages.Error.Type{
#      path: [:age],
#      text: "must be greater than 18",
#      meta: %{args: [18, 12], predicate: :gt?}
#    }
#  ]}
