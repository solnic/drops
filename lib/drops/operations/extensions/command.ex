defmodule Drops.Operations.Extensions.Command do
  @moduledoc """
  Command extension for Operations framework.

  This extension provides the basic command pattern implementation with
  prepare, validate, and execute steps. It defines the core pipeline
  for command operations.

  ## Pipeline Steps

  1. `prepare/1` - Prepares the context for validation and execution
  2. `validate/1` - Validates the prepared context
  3. `execute/1` - Executes the main operation logic (must be implemented)

  ## Usage

      defmodule CreateUser do
        use MyOperations, type: :command

        steps do
          @impl true
          def execute(%{params: params}) do
            # Implementation required
            {:ok, create_user(params)}
          end
        end
      end

  ## Callbacks

  Operations using this extension must implement:

  - `execute/1` - The main operation logic
  """
  use Drops.Operations.Extension

  @doc """
  Executes the main operation logic.

  This callback must be implemented by operations using the Command extension.
  It receives the validated context and should perform the core business logic.

  ## Parameters

  - `context` - A map containing the operation context, typically including:
    - `:params` - The validated input parameters
    - Additional keys added by previous steps

  ## Returns

  - `{:ok, result}` - Success with the operation result
  - `{:error, error}` - Failure with error details

  ## Example

      @impl true
      def execute(%{params: %{name: name, email: email}}) do
        case create_user(name, email) do
          {:ok, user} -> {:ok, user}
          {:error, reason} -> {:error, reason}
        end
      end
  """
  @callback execute(context :: map()) :: {:ok, any()} | {:error, any()}

  @impl true
  @spec unit_of_work(Drops.Operations.UnitOfWork.t(), keyword()) ::
          Drops.Operations.UnitOfWork.t()
  def unit_of_work(uow, _opts) do
    uow
    |> add_step(:prepare)
    |> add_step(:validate)
    |> add_step(:execute)
  end

  @impl true
  @spec using() :: Macro.t()
  def using do
    quote do
      @behaviour Drops.Operations.Extensions.Command
    end
  end

  steps do
    def prepare(context) do
      {:ok, context}
    end

    def validate(context) do
      {:ok, context}
    end

    @impl true
    def execute(_context) do
      raise "#{__MODULE__}.execute/1 must be implemented"
    end

    defoverridable prepare: 1, validate: 1, execute: 1
  end
end
