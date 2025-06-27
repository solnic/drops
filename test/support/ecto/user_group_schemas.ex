defmodule Test.Ecto.UserGroupSchemas do
  @moduledoc """
  Test schemas for User and Group associations used in cast/1 testing.
  """

  defmodule User do
    @moduledoc "User schema with many_to_many groups association"
    use Ecto.Schema
    import Ecto.Changeset

    schema "users" do
      field(:name, :string)
      field(:email, :string)

      many_to_many(:groups, Test.Ecto.UserGroupSchemas.Group, join_through: "user_groups")

      timestamps()
    end

    def changeset(user, attrs) do
      user
      |> cast(attrs, [:name, :email])
      |> validate_required([:name])
    end
  end

  defmodule Group do
    @moduledoc "Group schema with many_to_many users association"
    use Ecto.Schema
    import Ecto.Changeset

    schema "groups" do
      field(:name, :string)
      field(:description, :string)

      many_to_many(:users, Test.Ecto.UserGroupSchemas.User, join_through: "user_groups")

      timestamps()
    end

    def changeset(group, attrs) do
      group
      |> cast(attrs, [:name, :description])
      |> validate_required([:name])
    end
  end
end
