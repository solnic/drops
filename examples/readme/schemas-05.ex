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
#    %Drops.Contract.Messages.Error.Caster{
#      error: %Drops.Contract.Messages.Error.Type{
#        path: [:count],
#        text: "must be a string",
#        meta: %{args: [:string, nil], predicate: :type?}
#      }
#    }
#  ]}

UserContract.conform(%{count: "-1"})
# {:error,
#  [
#    %Drops.Contract.Messages.Error.Type{
#      path: [:count],
#      text: "must be greater than 0",
#      meta: %{args: [0, -1], predicate: :gt?}
#    }
#  ]}
