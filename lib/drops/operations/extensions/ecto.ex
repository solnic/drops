defmodule Drops.Operations.Extensions.Ecto do
  @moduledoc """
  Ecto extension for Operations.

  This extension adds Ecto-specific functionality to Operations modules when
  a repo is configured. It provides:

  - Changeset validation pipeline
  - `cast_changeset/2` and `validate/1` callbacks
  - `changeset/1` and `persist/1` functions
  - Phoenix.HTML.FormData protocol support for Success/Failure structs
  - Schema error conversion to changeset errors

  The extension is automatically enabled when the `:repo` option is provided.
  """

  @behaviour Drops.Operations.Extension

  @doc """
  Callback for validating an Ecto changeset.
  """
  @callback validate(changeset :: Ecto.Changeset.t()) :: Ecto.Changeset.t()

  @doc """
  Callback for casting and validating a changeset with new parameters.
  """
  @callback cast_changeset(params :: map(), changeset :: Ecto.Changeset.t()) ::
              Ecto.Changeset.t()

  @impl true
  def enabled?(opts) do
    Keyword.has_key?(opts, :repo) && !is_nil(opts[:repo])
  end

  @impl true
  def extend_using_macro(_opts) do
    quote do
      # No additional setup needed in the main __using__ macro
    end
  end

  @impl true
  def extend_operation_runtime(_opts) do
    quote do
      # Import Ecto.Changeset for changeset operations
      import Ecto.Changeset

      # Add persist delegation function (only needed at runtime)
      def persist(params) do
        Drops.Operations.Extensions.Ecto.persist(__MODULE__, params)
      end
    end
  end

  @impl true
  def extend_unit_of_work(uow, opts) do
    # Check if the operation uses an Ecto schema by examining compile-time metadata
    schema_meta = Keyword.get(opts, :schema_meta, %{})
    default_schema_meta = Map.get(schema_meta, :default, %{})
    has_ecto_schema = Map.get(default_schema_meta, :ecto_schema, false)

    if has_ecto_schema do
      # Inject Ecto steps only when there's an actual Ecto schema
      uow
      |> Drops.Operations.UnitOfWork.inject_step(
        :changeset,
        uow.operation_module,
        :changeset
      )
      |> Drops.Operations.UnitOfWork.inject_step(
        :cast_changeset,
        uow.operation_module,
        :cast_changeset
      )
      |> Drops.Operations.UnitOfWork.override_step(
        :validate,
        __MODULE__,
        :validate_changeset
      )
    else
      # No Ecto schema, return UoW unchanged
      uow
    end
  end

  @impl true
  def extend_operation_definition(opts) do
    quote location: :keep do
      # Import Ecto.Changeset for changeset operations
      import Ecto.Changeset

      # Always define these functions when Ecto extension is enabled
      # Default implementations that delegate to the extension module
      def cast_changeset(params, changeset) do
        Drops.Operations.Extensions.Ecto.cast_changeset(__MODULE__, params, changeset)
      end

      defoverridable cast_changeset: 2

      # Step 1: Create changeset from prepared params
      def changeset(params) do
        Drops.Operations.Extensions.Ecto.changeset(__MODULE__, params)
      end

      defoverridable changeset: 1

      # Default changeset validation function (overridable by users)
      def validate(%Ecto.Changeset{} = changeset) do
        Drops.Operations.Extensions.Ecto.validate(__MODULE__, changeset)
      end

      # Add persist function if repo is configured
      unquote(
        if opts[:repo] do
          quote do
            def persist(params) do
              Drops.Operations.Extensions.Ecto.persist(__MODULE__, params)
            end
          end
        end
      )

      # Helper function to convert schema validation errors to changeset errors
      defp convert_schema_errors_to_changeset(changeset, schema_errors) do
        Drops.Operations.Extensions.Ecto.convert_schema_errors_to_changeset(
          __MODULE__,
          changeset.params,
          schema_errors
        )
      end
    end
  end

  # Public API functions that operations delegate to

  @doc """
  Default cast_changeset implementation that returns the changeset unchanged.
  """
  def cast_changeset(_operation_module, _params, changeset) do
    changeset
  end

  @doc """
  Validates a changeset by calling the operation's validate function and then
  checking if the result is valid.

  This function is used as the :validate step in the UnitOfWork pipeline.
  """
  def validate_changeset(operation_module, changeset) do
    # Call the operation's validate function (which may be overridden by the user)
    validated_changeset = operation_module.validate(changeset)

    # Check if the changeset is valid
    validate(operation_module, validated_changeset)
  end

  @doc """
  Default validate implementation for Ecto changesets.

  This function checks if the changeset is valid. If it's invalid,
  it sets the action and returns an error tuple that will be handled
  by the UnitOfWork pipeline.
  """
  def validate(_operation_module, changeset) do
    if changeset.valid? do
      changeset
    else
      # For invalid changesets, set action and return error
      # This is needed for Phoenix.HTML.FormData to extract errors properly
      changeset_with_action = Map.put(changeset, :action, :validate)
      {:error, changeset_with_action}
    end
  end

  @doc """
  Creates a changeset from the operation's schema and provided parameters.
  """
  def changeset(operation_module, params) do
    schema = operation_module.schema()
    source_schema = schema.meta[:source_schema]

    if source_schema do
      # Create changeset and store original params for schema merging
      struct(source_schema)
      |> Ecto.Changeset.change(params)
      |> Map.put(:params, params)
    else
      # No Ecto schema - this shouldn't happen if UoW is set up correctly
      raise "changeset/1 called on operation without Ecto schema"
    end
  end

  @doc """
  Persists parameters using the configured repo.
  """
  def persist(operation_module, changeset) do
    operation_module.__repo__().insert(changeset)
  end

  # Helper function to check if operation has an Ecto schema
  def has_ecto_schema?(operation_module) do
    schema = operation_module.schema()
    !is_nil(schema.meta[:source_schema])
  end

  # Helper function to convert schema validation errors to changeset for form operations
  def convert_schema_errors_to_changeset(operation_module, params, errors) do
    # Convert string keys to atom keys for Ecto changeset compatibility
    atom_params = atomize_keys(params)

    # Create an empty changeset and add the schema errors to it
    changeset = operation_module.changeset(atom_params)

    Enum.reduce(errors, changeset, fn error, acc ->
      case error do
        # Handle Drops.Validator.Messages.Error.Type format
        %Drops.Validator.Messages.Error.Type{path: [field], text: text}
        when is_atom(field) ->
          Ecto.Changeset.add_error(acc, field, text)

        %Drops.Validator.Messages.Error.Type{path: [field], text: text}
        when is_binary(field) ->
          field_atom = String.to_existing_atom(field)
          Ecto.Changeset.add_error(acc, field_atom, text)

        # Handle nested paths by flattening to the first level for now
        %Drops.Validator.Messages.Error.Type{path: [field | _], text: text}
        when is_atom(field) ->
          Ecto.Changeset.add_error(acc, field, text)

        %Drops.Validator.Messages.Error.Type{path: [field | _], text: text}
        when is_binary(field) ->
          field_atom = String.to_existing_atom(field)
          Ecto.Changeset.add_error(acc, field_atom, text)

        # Handle generic error format with path and text
        %{path: [field], text: text} when is_atom(field) ->
          Ecto.Changeset.add_error(acc, field, text)

        %{path: [field], text: text} when is_binary(field) ->
          field_atom = String.to_existing_atom(field)
          Ecto.Changeset.add_error(acc, field_atom, text)

        # Handle nested paths by flattening to the first level for now
        %{path: [field | _], text: text} when is_atom(field) ->
          Ecto.Changeset.add_error(acc, field, text)

        %{path: [field | _], text: text} when is_binary(field) ->
          field_atom = String.to_existing_atom(field)
          Ecto.Changeset.add_error(acc, field_atom, text)

        # Handle legacy error format
        {key, {message, _opts}} ->
          Ecto.Changeset.add_error(acc, key, message)

        # Fallback for other error structures
        _ ->
          acc
      end
    end)
    |> Map.put(:action, :validate)
  end

  # Helper function to convert string keys to atom keys
  defp atomize_keys(map) when is_map(map) do
    Map.new(map, fn
      {key, value} when is_binary(key) ->
        try do
          {String.to_existing_atom(key), value}
        rescue
          ArgumentError -> {key, value}
        end

      {key, value} ->
        {key, value}
    end)
  end

  defp atomize_keys(other), do: other
end

# Phoenix.HTML.FormData protocol implementations for form compatibility
# These are only compiled if Phoenix.HTML is available
if Code.ensure_loaded?(Phoenix.HTML.FormData) do
  defimpl Phoenix.HTML.FormData, for: Drops.Operations.Success do
    def to_form(%{params: params, type: :form}, options) do
      # For :form operations, use the validated params as the form data
      # This allows the Success struct to work with Phoenix form helpers
      # Convert atom keys to string keys as required by Phoenix.HTML
      form_data = if is_map(params), do: stringify_keys(params), else: %{}
      create_form_struct(form_data, options, "success")
    end

    def to_form(%{params: params}, options) do
      # For non-form operations, fall back to params
      # Convert atom keys to string keys as required by Phoenix.HTML
      form_data = if is_map(params), do: stringify_keys(params), else: %{}
      create_form_struct(form_data, options, "success")
    end

    def to_form(data, form, field, options) do
      form_data = if is_map(data.params), do: stringify_keys(data.params), else: %{}
      Phoenix.HTML.FormData.to_form(form_data, form, field, options)
    end

    def input_value(%{params: params}, form, field) do
      form_data = if is_map(params), do: stringify_keys(params), else: %{}
      Phoenix.HTML.FormData.input_value(form_data, form, field)
    end

    def input_validations(%{params: _params}, _form, _field) do
      []
    end

    # Helper function to create a proper Phoenix.HTML.Form struct
    defp create_form_struct(form_data, options, default_name) do
      {name, options} = Keyword.pop(options, :as)
      name = to_string(name || default_name)
      id = Keyword.get(options, :id) || name

      %Phoenix.HTML.Form{
        source: form_data,
        impl: __MODULE__,
        id: id,
        name: name,
        data: form_data,
        params: form_data,
        errors: [],
        hidden: [],
        options: options,
        action: nil,
        index: nil
      }
    end

    # Helper function to convert atom keys to string keys
    defp stringify_keys(map) when is_map(map) do
      Map.new(map, fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        {key, value} -> {key, value}
      end)
    end

    defp stringify_keys(other), do: other
  end

  defimpl Phoenix.HTML.FormData, for: Drops.Operations.Failure do
    def to_form(
          %{operation: operation_module, params: params, result: result, type: :form},
          options
        ) do
      # For :form operations with validation errors, we want to preserve
      # the original params and include error information
      # Convert atom keys to string keys as required by Phoenix.HTML
      form_data = if is_map(params), do: stringify_keys(params), else: %{}

      # If result is an Ecto.Changeset, use it directly for form data
      # as it contains both data and errors
      case result do
        %Ecto.Changeset{} = changeset ->
          Phoenix.HTML.FormData.to_form(changeset, options)

        # For form operations with Ecto schemas, convert schema validation errors to changeset
        errors when is_list(errors) ->
          if Drops.Operations.Extensions.Ecto.has_ecto_schema?(operation_module) do
            changeset =
              Drops.Operations.Extensions.Ecto.convert_schema_errors_to_changeset(
                operation_module,
                params,
                errors
              )

            Phoenix.HTML.FormData.to_form(changeset, options)
          else
            create_form_struct(form_data, options, "failure")
          end

        _ ->
          create_form_struct(form_data, options, "failure")
      end
    end

    def to_form(%{params: params, result: result}, options) do
      # For non-form operations, check if result is a changeset
      case result do
        %Ecto.Changeset{} = changeset ->
          Phoenix.HTML.FormData.to_form(changeset, options)

        _ ->
          form_data = if is_map(params), do: stringify_keys(params), else: %{}
          create_form_struct(form_data, options, "failure")
      end
    end

    def to_form(data, form, field, options) do
      case data.result do
        %Ecto.Changeset{} = changeset ->
          Phoenix.HTML.FormData.to_form(changeset, form, field, options)

        _ ->
          form_data = if is_map(data.params), do: stringify_keys(data.params), else: %{}
          Phoenix.HTML.FormData.to_form(form_data, form, field, options)
      end
    end

    def input_value(%{params: params, result: result}, form, field) do
      case result do
        %Ecto.Changeset{} = changeset ->
          Phoenix.HTML.FormData.input_value(changeset, form, field)

        _ ->
          form_data = if is_map(params), do: stringify_keys(params), else: %{}
          Phoenix.HTML.FormData.input_value(form_data, form, field)
      end
    end

    def input_validations(%{params: _params, result: result}, form, field) do
      case result do
        %Ecto.Changeset{} = changeset ->
          Phoenix.HTML.FormData.input_validations(changeset, form, field)

        _ ->
          []
      end
    end

    # Helper function to create a proper Phoenix.HTML.Form struct
    defp create_form_struct(form_data, options, default_name) do
      {name, options} = Keyword.pop(options, :as)
      name = to_string(name || default_name)
      id = Keyword.get(options, :id) || name

      %Phoenix.HTML.Form{
        source: form_data,
        impl: __MODULE__,
        id: id,
        name: name,
        data: form_data,
        params: form_data,
        errors: [],
        hidden: [],
        options: options,
        action: nil,
        index: nil
      }
    end

    # Helper function to convert atom keys to string keys
    defp stringify_keys(map) when is_map(map) do
      Map.new(map, fn
        {key, value} when is_atom(key) -> {Atom.to_string(key), value}
        {key, value} -> {key, value}
      end)
    end

    defp stringify_keys(other), do: other
  end
end
