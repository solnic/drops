import Config

# Configure the test repository for examples in dev environment
config :drops, Drops.TestRepo,
  adapter: Ecto.Adapters.SQLite3,
  database: ":memory:",
  pool: Ecto.Adapters.SQL.Sandbox,
  pool_size: 10,
  queue_target: 5000,
  queue_interval: 1000,
  log: false

# Configure Ecto repos
config :drops, :ecto_repos, [Drops.TestRepo]

# Configure debug logging for development
config :drops, :logger,
  handler: :console,
  level: :debug,
  metadata: [
    :operation,
    :step,
    :context,
    :duration_us,
    :kind,
    :reason,
    :error_type,
    :errors
  ],
  formatter: %{
    format: :string,
    colorize: true
  }
