# Example: Custom Telemetry Prefix in Operations
#
# This example demonstrates how to configure custom telemetry event prefixes
# in the Operations module.

# First, let's create an Operations module with default telemetry
defmodule MyApp.Operations do
  use Drops.Operations, telemetry: true
end

# Create an Operations module with custom telemetry prefix
defmodule MyApp.CustomOperations do
  use Drops.Operations, 
    telemetry: true, 
    telemetry_prefix: [:my_app, :operations]
end

# Example operation using default telemetry
defmodule MyApp.CreateUser do
  use MyApp.Operations, type: :command

  schema do
    %{
      required(:name) => string(:filled?),
      required(:email) => string(:filled?)
    }
  end

  @impl true
  def execute(%{params: params}) do
    {:ok, %{id: 1, name: params.name, email: params.email}}
  end
end

# Example operation using custom telemetry prefix
defmodule MyApp.UpdateUser do
  use MyApp.CustomOperations, type: :command

  schema do
    %{
      required(:id) => integer(),
      required(:name) => string(:filled?)
    }
  end

  @impl true
  def execute(%{params: params}) do
    {:ok, %{id: params.id, name: params.name, updated_at: DateTime.utc_now()}}
  end
end

# You can also override the prefix per operation
defmodule MyApp.DeleteUser do
  use MyApp.Operations, 
    type: :command, 
    telemetry: true,
    telemetry_prefix: [:my_app, :user_operations]

  schema do
    %{
      required(:id) => integer()
    }
  end

  @impl true
  def execute(%{params: params}) do
    {:ok, %{deleted_id: params.id}}
  end
end

# Example telemetry handler
defmodule MyApp.TelemetryHandler do
  def handle_event(event, measurements, metadata, _config) do
    IO.puts("Event: #{inspect(event)}")
    IO.puts("Measurements: #{inspect(measurements)}")
    IO.puts("Metadata: #{inspect(metadata)}")
    IO.puts("---")
  end
end

# Attach handlers for different prefixes
:telemetry.attach_many(
  "default-operations-handler",
  [
    [:drops, :operations, :step, :start],
    [:drops, :operations, :step, :stop]
  ],
  &MyApp.TelemetryHandler.handle_event/4,
  %{}
)

:telemetry.attach_many(
  "custom-operations-handler", 
  [
    [:my_app, :operations, :step, :start],
    [:my_app, :operations, :step, :stop]
  ],
  &MyApp.TelemetryHandler.handle_event/4,
  %{}
)

:telemetry.attach_many(
  "user-operations-handler",
  [
    [:my_app, :user_operations, :step, :start],
    [:my_app, :user_operations, :step, :stop]
  ],
  &MyApp.TelemetryHandler.handle_event/4,
  %{}
)

# Example usage:
IO.puts("=== Default telemetry prefix ([:drops, :operations]) ===")
MyApp.CreateUser.call(%{name: "Alice", email: "alice@example.com"})

IO.puts("\n=== Custom telemetry prefix ([:my_app, :operations]) ===")
MyApp.UpdateUser.call(%{id: 1, name: "Alice Updated"})

IO.puts("\n=== Per-operation telemetry prefix ([:my_app, :user_operations]) ===")
MyApp.DeleteUser.call(%{id: 1})

# Clean up handlers
:telemetry.detach("default-operations-handler")
:telemetry.detach("custom-operations-handler")
:telemetry.detach("user-operations-handler")
