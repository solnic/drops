# Example: Telemetry Configuration in Operations
#
# This example demonstrates the different telemetry configuration options
# available in the Operations module, including the new default behavior.

# First, let's create an Operations module with default telemetry
# This now emits operation-level events by default (new behavior)
defmodule MyApp.Operations do
  use Drops.Operations, telemetry: true
end

# Create an Operations module with custom telemetry prefix for operation-level events
defmodule MyApp.CustomOperations do
  use Drops.Operations,
    telemetry: [prefix: [:my_app, :operations]]
end

# Create an Operations module with step-level telemetry (backward compatibility)
defmodule MyApp.StepOperations do
  use Drops.Operations,
    telemetry: :steps
end

# Example operation using default operation-level telemetry
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

# Example operation using custom telemetry prefix for operation-level events
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

# Example operation using step-level telemetry (backward compatibility)
defmodule MyApp.ProcessUser do
  use MyApp.StepOperations, type: :command

  schema do
    %{
      required(:id) => integer(),
      required(:action) => string(:filled?)
    }
  end

  @impl true
  def execute(%{params: params}) do
    {:ok, %{id: params.id, action: params.action, processed_at: DateTime.utc_now()}}
  end
end

# You can also configure telemetry per operation with different levels
defmodule MyApp.DeleteUser do
  use MyApp.Operations,
    type: :command,
    telemetry: [level: :both, prefix: [:my_app, :user_operations]]

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
    event_type = event |> Enum.at(2) # :operation or :step
    action = List.last(event) # :start or :stop

    case {event_type, action} do
      {:operation, :start} ->
        IO.puts("🚀 Operation #{metadata.operation} started (#{metadata.operation_type})")

      {:operation, :stop} ->
        duration_ms = measurements.duration / 1_000_000
        IO.puts("✅ Operation #{metadata.operation} completed in #{Float.round(duration_ms, 2)}ms")

      {:step, :start} ->
        IO.puts("  ⏳ Step #{metadata.step} starting...")

      {:step, :stop} ->
        duration_ms = measurements.duration / 1_000_000
        IO.puts("  ✓ Step #{metadata.step} completed in #{Float.round(duration_ms, 2)}ms")
    end
  end
end

# Attach handlers for operation-level events (default behavior)
:telemetry.attach_many(
  "default-operations-handler",
  [
    [:drops, :operations, :operation, :start],
    [:drops, :operations, :operation, :stop]
  ],
  &MyApp.TelemetryHandler.handle_event/4,
  %{}
)

:telemetry.attach_many(
  "custom-operations-handler",
  [
    [:my_app, :operations, :operation, :start],
    [:my_app, :operations, :operation, :stop]
  ],
  &MyApp.TelemetryHandler.handle_event/4,
  %{}
)

# Attach handlers for step-level events (backward compatibility)
:telemetry.attach_many(
  "step-operations-handler",
  [
    [:drops, :operations, :step, :start],
    [:drops, :operations, :step, :stop]
  ],
  &MyApp.TelemetryHandler.handle_event/4,
  %{}
)

# Attach handlers for both operation and step events (for DeleteUser)
:telemetry.attach_many(
  "user-operations-handler",
  [
    [:my_app, :user_operations, :operation, :start],
    [:my_app, :user_operations, :operation, :stop],
    [:my_app, :user_operations, :step, :start],
    [:my_app, :user_operations, :step, :stop]
  ],
  &MyApp.TelemetryHandler.handle_event/4,
  %{}
)

# Example usage:
IO.puts("=== Default operation-level telemetry ([:drops, :operations]) ===")
MyApp.CreateUser.call(%{name: "Alice", email: "alice@example.com"})

IO.puts("\n=== Custom operation-level telemetry prefix ([:my_app, :operations]) ===")
MyApp.UpdateUser.call(%{id: 1, name: "Alice Updated"})

IO.puts("\n=== Step-level telemetry (backward compatibility) ===")
MyApp.ProcessUser.call(%{id: 2, action: "activate"})

IO.puts("\n=== Both operation and step-level telemetry ([:my_app, :user_operations]) ===")
MyApp.DeleteUser.call(%{id: 1})

# Clean up handlers
:telemetry.detach("default-operations-handler")
:telemetry.detach("custom-operations-handler")
:telemetry.detach("step-operations-handler")
:telemetry.detach("user-operations-handler")
