defmodule Drops.Operations.Extensions.Ecto do
  @moduledoc """
  Ecto extension for Operations framework.

  This extension provides integration with Ecto for database operations.
  It adds changeset creation and validation steps to the pipeline and
  provides helper functions for database operations.

  ## Features

  - Automatic changeset creation from operation parameters
  - Ecto schema integration with parameter validation
  - Database operation helpers (insert, update)
  - Customizable struct creation and changeset validation

  ## Requirements

  This extension requires a `:repo` option to be provided and will only
  be enabled when a repository is configured.

  ## Usage

      defmodule CreateUser do
        use MyOperations,
          type: :command,
          repo: MyApp.Repo

        schema(MyApp.User)

        steps do
          @impl true
          def execute(%{changeset: changeset}) do
            case insert(changeset) do
              {:ok, user} -> {:ok, user}
              {:error, changeset} -> {:error, changeset}
            end
          end
        end
      end

  ## Pipeline Steps

  This extension adds a `changeset` step after the `prepare` step that:
  1. Creates a struct using `get_struct/1`
  2. Creates a changeset from the struct and parameters
  3. Validates the changeset using `validate_changeset/1`

  ## Callbacks

  Operations using this extension can implement:

  - `get_struct/1` - Custom struct creation logic
  - `validate_changeset/1` - Custom changeset validation logic
  """
  use Drops.Operations.Extension

  @doc """
  Creates a struct for changeset creation.

  This callback allows operations to customize how the initial struct
  is created before building the changeset. The default implementation
  creates a new struct of the schema type.

  ## Parameters

  - `context` - The operation context containing `:params`

  ## Returns

  A struct instance that will be used for changeset creation.

  ## Example

      @impl true
      def get_struct(%{params: %{id: id}}) when not is_nil(id) do
        # For updates, fetch existing record
        Repo.get!(User, id)
      end

      def get_struct(%{params: _params}) do
        # For creates, use new struct
        %User{}
      end
  """
  @callback get_struct(context :: map()) :: struct()

  @doc """
  Validates the changeset with custom business logic.

  This callback allows operations to add custom validation logic
  beyond what's defined in the Ecto schema. The default implementation
  returns the changeset unchanged.

  ## Parameters

  - `context` - The operation context containing `:changeset`

  ## Returns

  The validated Ecto changeset.

  ## Example

      @impl true
      def validate_changeset(%{changeset: changeset}) do
        changeset
        |> validate_required([:name, :email])
        |> validate_format(:email, ~r/@/)
        |> validate_unique_email()
      end

      defp validate_unique_email(changeset) do
        email = get_change(changeset, :email)
        if email && email_exists?(email) do
          add_error(changeset, :email, "already exists")
        else
          changeset
        end
      end
  """
  @callback validate_changeset(context :: map()) :: Ecto.Changeset.t()

  @impl true
  @spec default_opts(keyword()) :: keyword()
  def default_opts(opts) do
    [schema: [cast: true, atomize: opts[:type] == :form]]
  end

  @impl true
  @spec enable?(keyword()) :: boolean()
  def enable?(opts) do
    Keyword.has_key?(opts, :repo) && !is_nil(opts[:repo])
  end

  @impl true
  @spec unit_of_work(Drops.Operations.UnitOfWork.t(), keyword()) ::
          Drops.Operations.UnitOfWork.t()
  def unit_of_work(uow, _opts) do
    after_step(uow, :prepare, :changeset)
  end

  @impl true
  @spec using() :: Macro.t()
  def using do
    quote do
      @behaviour Drops.Operations.Extensions.Ecto

      import Ecto.Changeset

      def ecto_schema, do: schema().meta[:source_schema]

      def repo, do: __opts__()[:repo]

      def insert(changeset) do
        repo().insert(%{changeset | action: :insert})
      end

      def update(changeset) do
        repo().update(%{changeset | action: :update})
      end

      @impl true
      def validate_changeset(%{changeset: changeset}) do
        changeset
      end

      @impl true
      def get_struct(%{params: _params}) do
        struct(ecto_schema())
      end

      defp cast_embedded_fields(changeset, embedded_fields, params) do
        Enum.reduce(embedded_fields, changeset, fn field, acc ->
          if Map.has_key?(params, field) do
            cast_embed(acc, field)
          else
            acc
          end
        end)
      end

      defoverridable validate_changeset: 1, get_struct: 1
    end
  end

  steps do
    def changeset(%{params: params} = context) do
      struct = get_struct(context)
      schema_module = ecto_schema()
      embedded_fields = schema_module.__schema__(:embeds)

      changeset = change(struct, params)
      changeset = cast_embedded_fields(changeset, embedded_fields, params)

      {:ok, Map.put(context, :changeset, changeset)}
    end

    def validate(%{changeset: changeset} = context) do
      case validate_changeset(%{context | changeset: %{changeset | action: :validate}}) do
        %{valid?: true} = changeset ->
          {:ok, %{context | changeset: %{changeset | action: nil}}}

        changeset ->
          {:error, changeset}
      end
    end

    defoverridable changeset: 1, validate: 1
  end
end
