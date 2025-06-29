defmodule Drops.DataCase do
  use ExUnit.CaseTemplate

  using do
    quote do
      use Drops.ContractCase

      alias Drops.TestRepo

      import Ecto
      import Ecto.Changeset
      import Ecto.Query
      import Drops.DataCase
    end
  end

  setup tags do
    Drops.DataCase.setup_sandbox(tags)

    # Run migrations for any Ecto schemas specified in tags
    if schemas = tags[:ecto_schemas] do
      # Check if we need User/Group schemas and run the migration
      user_group_schemas = [
        Test.Ecto.UserGroupSchemas.User,
        Test.Ecto.UserGroupSchemas.Group
      ]

      if Enum.any?(schemas, &(&1 in user_group_schemas)) do
        run_migration(Drops.TestRepo.Migrations.CreateUsersAndGroups)
        seed_test_groups()
      end

      # Create tables for any other Ecto schemas
      Enum.each(schemas, fn schema ->
        unless schema in user_group_schemas do
          create_table_for_schema(schema)
          create_join_tables_for_schema(schema)
        end
      end)
    end

    :ok
  end

  @doc """
  Sets up the sandbox based on the test tags.
  """
  def setup_sandbox(tags) do
    pid = Ecto.Adapters.SQL.Sandbox.start_owner!(Drops.TestRepo, shared: not tags[:async])
    on_exit(fn -> Ecto.Adapters.SQL.Sandbox.stop_owner(pid) end)
  end

  @doc """
  Runs a migration module programmatically.
  """
  def run_migration(_migration_module) do
    # Check if migration has already been run by looking for the tables
    case Ecto.Adapters.SQL.query(
           Drops.TestRepo,
           "SELECT name FROM sqlite_master WHERE type='table' AND name='users';"
         ) do
      {:ok, %{rows: []}} ->
        # Tables don't exist, create them
        create_users_and_groups_tables()

      _ ->
        # Tables already exist, skip
        :ok
    end
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
    # Insert test groups that the tests can reference
    now = DateTime.utc_now() |> DateTime.truncate(:second)

    Ecto.Adapters.SQL.query!(Drops.TestRepo, """
    INSERT INTO groups (id, name, description, inserted_at, updated_at) VALUES
    (1, 'Admins', 'Administrator group', '#{now}', '#{now}'),
    (2, 'Users', 'Regular users group', '#{now}', '#{now}')
    """)
  end

  @doc """
  Creates a table based on an Ecto schema module.
  Automatically generates CREATE TABLE statement from schema definition.
  """
  def create_table_for_schema(schema_module) do
    table_name = schema_module.__schema__(:source)

    # Skip embedded schemas (they don't have tables)
    if table_name == nil do
      :ok
    else
      fields = schema_module.__schema__(:fields)

      # Filter out virtual fields and associations, but include foreign keys
      real_fields =
        fields
        |> Enum.filter(fn field ->
          type = schema_module.__schema__(:type, field)
          not is_association_type?(type) and not is_virtual_field?(schema_module, field)
        end)

      # Add foreign key fields from belongs_to associations
      foreign_key_fields = get_foreign_key_fields(schema_module)
      all_fields = real_fields ++ foreign_key_fields

      field_definitions =
        all_fields
        |> Enum.uniq()
        |> Enum.map(&field_definition(schema_module, &1))
        |> Enum.join(",\n        ")

      # Check if schema has timestamps
      has_timestamps = :inserted_at in fields and :updated_at in fields

      timestamp_fields =
        if has_timestamps,
          do: ",\n        inserted_at DATETIME,\n        updated_at DATETIME",
          else: ""

      sql = """
        CREATE TABLE #{table_name} (
          id INTEGER PRIMARY KEY AUTOINCREMENT,
          #{field_definitions}#{timestamp_fields}
        )
      """

      Ecto.Adapters.SQL.query!(Drops.TestRepo, sql)
    end
  end

  @doc """
  Creates join tables for many-to-many associations in an Ecto schema.
  """
  def create_join_tables_for_schema(schema_module) do
    try do
      schema_module.__schema__(:associations)
      |> Enum.each(fn assoc_name ->
        assoc = schema_module.__schema__(:association, assoc_name)

        if assoc.__struct__ == Ecto.Association.ManyToMany do
          create_join_table(assoc.join_through, assoc.owner_key, assoc.related_key)
        end
      end)
    rescue
      _ -> :ok
    end
  end

  # Create a join table for many-to-many associations
  defp create_join_table(table_name, owner_key, related_key) do
    # Check if table already exists
    check_sql = """
    SELECT name FROM sqlite_master WHERE type='table' AND name='#{table_name}';
    """

    case Ecto.Adapters.SQL.query(Drops.TestRepo, check_sql) do
      {:ok, %{rows: []}} ->
        # Table doesn't exist, create it
        sql = """
        CREATE TABLE #{table_name} (
          #{owner_key} INTEGER NOT NULL,
          #{related_key} INTEGER NOT NULL,
          PRIMARY KEY (#{owner_key}, #{related_key})
        );
        """

        Ecto.Adapters.SQL.query!(Drops.TestRepo, sql)

      _ ->
        # Table already exists, skip
        :ok
    end
  end

  # Get foreign key fields from belongs_to associations
  defp get_foreign_key_fields(schema_module) do
    try do
      schema_module.__schema__(:associations)
      |> Enum.filter(fn assoc_name ->
        assoc = schema_module.__schema__(:association, assoc_name)
        assoc.__struct__ == Ecto.Association.BelongsTo
      end)
      |> Enum.map(fn assoc_name ->
        assoc = schema_module.__schema__(:association, assoc_name)
        assoc.owner_key
      end)
    rescue
      _ -> []
    end
  end

  # Private helper to generate field definition for CREATE TABLE
  defp field_definition(schema_module, field) do
    type = schema_module.__schema__(:type, field)
    sql_type = ecto_type_to_sql(type)
    "#{field} #{sql_type}"
  end

  # Check if a field type represents an association
  defp is_association_type?({:assoc, _}), do: true
  # Embeds are stored as JSON
  defp is_association_type?({:embed, _}), do: false
  defp is_association_type?(_), do: false

  # Check if a field is virtual (not stored in database)
  defp is_virtual_field?(schema_module, field) do
    # This is a simplified check - in a real implementation you might need
    # to inspect the schema's field options more thoroughly
    field in [:id, :inserted_at, :updated_at] or
      try do
        # Try to get field source - virtual fields might not have one
        schema_module.__schema__(:field_source, field) == nil
      rescue
        _ -> false
      end
  end

  # Convert Ecto types to SQLite types
  defp ecto_type_to_sql(:string), do: "TEXT"
  defp ecto_type_to_sql(:integer), do: "INTEGER"
  defp ecto_type_to_sql(:float), do: "REAL"
  defp ecto_type_to_sql(:boolean), do: "BOOLEAN"
  defp ecto_type_to_sql(:date), do: "DATE"
  defp ecto_type_to_sql(:time), do: "TIME"
  defp ecto_type_to_sql(:naive_datetime), do: "DATETIME"
  defp ecto_type_to_sql(:utc_datetime), do: "DATETIME"
  defp ecto_type_to_sql(:map), do: "JSON"
  defp ecto_type_to_sql({:map, _}), do: "JSON"
  defp ecto_type_to_sql({:array, _}), do: "JSON"
  defp ecto_type_to_sql({:embed, _}), do: "JSON"
  defp ecto_type_to_sql({:parameterized, Ecto.Embedded, _}), do: "JSON"
  defp ecto_type_to_sql(_), do: "TEXT"
end

# Setup Ecto for testing
if Mix.env() == :test do
  # Configure the test repository
  Application.put_env(:drops, Drops.TestRepo,
    adapter: Ecto.Adapters.SQLite3,
    database: ":memory:",
    pool: Ecto.Adapters.SQL.Sandbox,
    pool_size: 10,
    queue_target: 5000,
    queue_interval: 1000,
    log: false
  )

  # Configure Ecto repos
  Application.put_env(:drops, :ecto_repos, [Drops.TestRepo])

  # Load test support files
  Code.require_file("test_repo.ex", __DIR__)
  Code.require_file("ecto/test_schemas.ex", __DIR__)
  Code.require_file("ecto/user_group_schemas.ex", __DIR__)

  # Define test schemas that are commonly used across tests
  defmodule Test.Ecto.UserWithAddressSchema do
    @moduledoc "Test schema with embedded address for operations testing"
    use Ecto.Schema

    schema "users_with_address" do
      field(:name, :string)
      field(:email, :string)

      embeds_one(:address, Address) do
        field(:street, :string)
        field(:city, :string)
        field(:state, :string)
        field(:zip_code, :string)
        field(:country, :string)
      end

      timestamps()
    end
  end

  # Start dependencies
  {:ok, _} = Application.ensure_all_started(:ecto_sql)
  {:ok, _} = Drops.TestRepo.start_link()

  # Set up the SQL sandbox
  Ecto.Adapters.SQL.Sandbox.mode(Drops.TestRepo, :manual)
end
