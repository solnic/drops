defmodule Drops.Operations.Extensions.Params do
  @moduledoc """
  Params extension for Operations framework.

  This extension provides parameter validation and transformation using
  Drops contracts. It automatically adds a `conform` step to the pipeline
  when a schema is defined.

  ## Features

  - Automatic schema-based parameter validation
  - Parameter transformation and coercion
  - Integration with Drops.Contract for schema definition
  - Conditional pipeline modification based on schema presence

  ## Usage

      defmodule CreateUser do
        use MyOperations, type: :command

        schema do
          %{
            required(:name) => string(:filled?),
            required(:email) => string(:email?)
          }
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            # params are already validated and conformed
            {:ok, create_user(params)}
          end
        end
      end

  ## Pipeline Modification

  When a non-empty schema is defined, this extension adds a `conform` step
  before the `prepare` step to validate and transform input parameters.
  """
  use Drops.Operations.Extension

  @impl true
  @spec using() :: Macro.t()
  def using do
    quote do
      use Drops.Contract

      @schema_opts Keyword.get(@opts, :schema, [])

      schema do
        %{}
      end

      def conform(%{params: params} = context) do
        case super(params) do
          {:ok, conformed_params} ->
            {:ok, Map.put(context, :params, conformed_params)}

          {:error, _} = error ->
            error
        end
      end
    end
  end

  @impl true
  @spec unit_of_work(Drops.Operations.UnitOfWork.t(), keyword()) ::
          Drops.Operations.UnitOfWork.t()
  def unit_of_work(uow, _opts) do
    schemas = Module.get_attribute(uow.module, :schemas)
    schema = schemas[:default]

    if not is_nil(schema) and schema.keys != [] do
      before_step(uow, :prepare, :conform)
    else
      uow
    end
  end
end
