# Example: SaveUser Operation using Command Extension with Ecto Schema
#
# This example demonstrates how to create an operation that saves a user
# to the database using the Command extension with Ecto schema inference.
#
# Run with: mix drops.example examples/ecto/save_user_operation.exs

# Load the setup for examples
Code.require_file("examples/setup.exs")

_pid = ExampleSetup.setup_database([Test.Ecto.TestSchemas.UserSchema])

defmodule SaveUser do
  use Drops.Operations.Command, repo: Drops.TestRepo, debug: true

  schema(Test.Ecto.TestSchemas.UserSchema)

  steps do
    @impl true
    def execute(%{changeset: changeset}) do
      insert(changeset)
    end
  end

  def validate_changeset(%{changeset: changeset}) do
    changeset
    |> validate_required([:name, :email])
  end
end

valid_params = %{
  name: "John Doe",
  email: "john@example.com"
}

SaveUser.call(%{params: valid_params})

invalid_params = %{
  email: "jane@example.com",
  name: ""
}

SaveUser.call(%{params: invalid_params})
