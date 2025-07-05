# Setup file for examples environment
# This file is automatically loaded when running examples with `mix run examples/...`

# Only run setup if we're in dev environment (where examples run)
if Mix.env() == :dev do
  # Load test support files that contain our schemas
  Code.require_file("test_repo.ex", "test/support")
  Code.require_file("ecto/test_schemas.ex", "test/support")
  Code.require_file("ecto/user_group_schemas.ex", "test/support")

  # Start dependencies
  {:ok, _} = Application.ensure_all_started(:drops)
  {:ok, _} = Application.ensure_all_started(:ecto_sql)
  {:ok, _} = Drops.TestRepo.start_link()

  # Set up the SQL sandbox for examples
  Ecto.Adapters.SQL.Sandbox.mode(Drops.TestRepo, :manual)

  # Helper function to set up database for examples
  defmodule ExampleSetup do
    @moduledoc """
    Helper functions for setting up database state in examples.
    """

    @doc """
    Sets up the database with the necessary tables for the given schemas.
    Call this at the beginning of your example if you need database access.
    """
    def setup_database(schemas \\ []) do
      # Start a sandbox transaction
      pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Drops.TestRepo, shared: false)

      # Set up tables for the schemas
      setup_schemas(schemas)

      # Return the pid so examples can clean up if needed
      pid
    end

    @doc """
    Clean up the database sandbox.
    """
    def cleanup_database(pid) do
      Ecto.Adapters.SQL.Sandbox.stop_owner(pid)
    end

    defp setup_schemas(schemas) do
      # Check if we need User/Group schemas and run the migration
      user_group_schemas = [
        Test.Ecto.TestSchemas.UserSchema,
        Test.Ecto.UserGroupSchemas.User,
        Test.Ecto.UserGroupSchemas.Group
      ]

      if Enum.any?(schemas, &(&1 in user_group_schemas)) do
        create_users_and_groups_tables()
        seed_test_groups()
      end

      # Create tables for any other schemas
      Enum.each(schemas, fn schema ->
        unless schema in user_group_schemas do
          create_table_for_schema(schema)
        end
      end)
    end

    defp create_users_and_groups_tables do
      # Create users table
      Ecto.Adapters.SQL.query!(Drops.TestRepo, """
      CREATE TABLE users (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        email TEXT,
        inserted_at DATETIME,
        updated_at DATETIME
      )
      """)

      # Create groups table
      Ecto.Adapters.SQL.query!(Drops.TestRepo, """
      CREATE TABLE groups (
        id INTEGER PRIMARY KEY AUTOINCREMENT,
        name TEXT NOT NULL,
        description TEXT,
        inserted_at DATETIME,
        updated_at DATETIME
      )
      """)

      # Create join table
      Ecto.Adapters.SQL.query!(Drops.TestRepo, """
      CREATE TABLE user_groups (
        user_id INTEGER NOT NULL,
        group_id INTEGER NOT NULL,
        PRIMARY KEY (user_id, group_id),
        FOREIGN KEY (user_id) REFERENCES users(id) ON DELETE CASCADE,
        FOREIGN KEY (group_id) REFERENCES groups(id) ON DELETE CASCADE
      )
      """)

      # Create unique index
      Ecto.Adapters.SQL.query!(Drops.TestRepo, """
      CREATE UNIQUE INDEX user_groups_user_id_group_id_index ON user_groups (user_id, group_id)
      """)
    end

    defp seed_test_groups do
      # Insert test groups that examples can reference
      now = DateTime.utc_now() |> DateTime.truncate(:second)

      Ecto.Adapters.SQL.query!(Drops.TestRepo, """
      INSERT INTO groups (id, name, description, inserted_at, updated_at) VALUES
      (1, 'Admins', 'Administrator group', '#{now}', '#{now}'),
      (2, 'Users', 'Regular users group', '#{now}', '#{now}')
      """)
    end

    defp create_table_for_schema(schema) do
      # This is a simplified version - for complex schemas you might need more logic
      table_name = schema.__schema__(:source)

      # For now, just create a basic table - examples can extend this as needed
      IO.puts(
        "Note: You may need to manually create table '#{table_name}' for schema #{inspect(schema)}"
      )
    end
  end
end
