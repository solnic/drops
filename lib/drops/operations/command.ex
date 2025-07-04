defmodule Drops.Operations.Command do
  @moduledoc """
  Preconfigured Operations module for your application commands with processing pipeline that consists of:

  1. `conform` - Validates input against the schema and transforms it
  2. `prepare` - Prepares the conformed parameters for validation
  3. `validate` - Validates the prepared parameters
  4. `execute` - Executes the operation with validated parameters

  ## Usage

      defmodule CreateUser do
        use Drops.Operations.Command

        schema do
          %{
            required(:name) => string(:filled?),
            required(:email) => string(:email?)
          }
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            case MyApp.create_user(params) do
              {:ok, user} -> {:ok, user}
              {:error, reason} -> {:error, reason}
            end
          end
        end
      end

  See `Drops.Operations.Extensions.Command` for more information on specific processing steps.
  """
  @moduledoc since: "0.3.0"

  use Drops.Operations,
    type: :command,
    extensions: [
      Drops.Operations.Extensions.Command,
      Drops.Operations.Extensions.Params,
      Drops.Operations.Extensions.Ecto
    ]
end
