import Config

# Suppress console log output during tests
config :logger, level: :warning

# Configure the debug handler to use memory for testing
config :drops, :logger,
  handler: :memory,
  level: :debug,
  format: "[$level] $message $metadata\n",
  metadata: [:operation, :step]
