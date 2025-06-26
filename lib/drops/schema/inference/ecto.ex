defimpl Drops.Schema.Compiler, for: Atom do
  @moduledoc """
  Custom compiler for Ecto schema modules.

  This implementation adds the source Ecto schema module to the compiled
  Map type's meta field, allowing users to access the original schema
  information after compilation.
  """

  alias Drops.Type.Compiler, as: DefaultCompiler

  @doc """
  Compile a schema AST from an Ecto schema module with meta information.

  This function compiles the schema AST using the default compiler but
  adds the source Ecto schema module to the resulting Map type's meta field.

  ## Parameters

  - `ecto_schema_module` - The Ecto schema module that was used for inference
  - `schema_ast` - The schema AST returned by inference
  - `opts` - Compilation options

  ## Returns

  Returns a compiled Map type with the source schema in its meta field.
  """
  def compile(ecto_schema_module, schema_ast, opts) when is_atom(ecto_schema_module) do
    # Check if this is an Ecto schema module
    if ecto_schema_module?(ecto_schema_module) do
      # Add the source schema to the meta field
      opts_with_meta =
        Keyword.update(
          opts,
          :meta,
          %{source_schema: ecto_schema_module},
          fn existing_meta ->
            Map.put(existing_meta, :source_schema, ecto_schema_module)
          end
        )

      # Use the default compiler with the enhanced options
      DefaultCompiler.visit(schema_ast, opts_with_meta)
    else
      # For non-Ecto atoms, use the default compiler as-is
      DefaultCompiler.visit(schema_ast, opts)
    end
  end

  # Private helper function
  defp ecto_schema_module?(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :__schema__, 1)
  end
end

defimpl Drops.Schema.Inference, for: Atom do
  @moduledoc """
  Schema inference implementation for Ecto schema modules.

  This implementation handles the inference of schemas from Ecto schema modules
  by introspecting their field definitions and converting them to Drops schema format.

  ## Examples

      # Given an Ecto schema:
      defmodule User do
        use Ecto.Schema

        schema "users" do
          field(:name, :string)
          field(:email, :string)
          field(:age, :integer)
          timestamps()
        end
      end

      # Inference will produce:
      %{
        required(:name) => string(),
        required(:email) => string(),
        required(:age) => integer()
      }

  ## Field Filtering

  By default, the following fields are excluded from inference:
  - `:id` - Primary key field
  - `:inserted_at` - Timestamp field
  - `:updated_at` - Timestamp field

  This can be customized via options.

  ## Field Presence

  By default, all fields are marked as required. This can be customized
  by providing field presence configuration in the options.
  """

  import Drops.Type.DSL

  @doc """
  Infer schema from an Ecto schema module.

  ## Parameters

  - `module` - An Ecto schema module
  - `opts` - Options for inference:
    - `:exclude_fields` - List of field names to exclude (default: `[:id, :inserted_at, :updated_at]`)
    - `:field_presence` - Map of field names to presence (`:required` or `:optional`)
    - `:default_presence` - Default presence for fields (default: `:required`)

  ## Returns

  Returns a Map schema definition compatible with Drops.

  ## Examples

      # Basic inference
      Drops.Schema.Inference.infer_schema(MyApp.User, [])

      # Custom field presence
      Drops.Schema.Inference.infer_schema(MyApp.User,
        field_presence: %{name: :required, email: :required},
        default_presence: :optional
      )

      # Include all fields
      Drops.Schema.Inference.infer_schema(MyApp.User, exclude_fields: [])
  """
  def infer_schema(module, opts) when is_atom(module) do
    # Check if this is an Ecto schema module
    if ecto_schema_module?(module) do
      infer_ecto_schema(module, opts)
    else
      # For non-Ecto atoms, we can't infer a schema
      raise ArgumentError,
            "Cannot infer schema from atom #{inspect(module)} - not an Ecto schema module"
    end
  end

  # Private functions

  defp ecto_schema_module?(module) do
    Code.ensure_loaded?(module) and
      function_exported?(module, :__schema__, 1)
  end

  defp infer_ecto_schema(module, opts) do
    field_presence = Keyword.get(opts, :field_presence, %{})
    default_presence = Keyword.get(opts, :default_presence, :required)

    # Get all fields from the Ecto schema
    all_fields = module.__schema__(:fields)

    # Determine which fields to include
    fields =
      if accept_fields = Keyword.get(opts, :accept) do
        # If :accept is specified, only include those fields
        Enum.filter(all_fields, &(&1 in accept_fields))
      else
        # Otherwise, use the existing exclude_fields logic
        default_exclude = [:id, :inserted_at, :updated_at]

        # If exclude_fields is explicitly provided, use it as-is
        # Otherwise, use the default exclusions
        exclude_fields =
          if Keyword.has_key?(opts, :exclude_fields) do
            user_exclude = Keyword.get(opts, :exclude_fields)
            # If user provides an empty list, they want all fields
            if user_exclude == [] do
              []
            else
              # Combine user exclusions with defaults
              (default_exclude ++ user_exclude) |> Enum.uniq()
            end
          else
            default_exclude
          end

        # Filter out excluded fields
        Enum.reject(all_fields, &(&1 in exclude_fields))
      end

    # Convert each field to a Drops schema entry
    field_entries =
      Enum.map(fields, fn field ->
        field_type = module.__schema__(:type, field)
        drops_type = ecto_type_to_drops_type(field_type)

        # Determine field presence
        presence = Map.get(field_presence, field, default_presence)

        presence_key =
          case presence do
            :required -> required(field)
            :optional -> optional(field)
            # Default to optional for unknown values
            _ -> optional(field)
          end

        {presence_key, drops_type}
      end)

    # Return a map with the field entries
    Map.new(field_entries)
  end

  # Type mapping from Ecto types to Drops types

  # Basic primitive types
  defp ecto_type_to_drops_type(:string), do: string()
  defp ecto_type_to_drops_type(:integer), do: integer()
  defp ecto_type_to_drops_type(:float), do: float()
  defp ecto_type_to_drops_type(:boolean), do: boolean()

  # ID types
  defp ecto_type_to_drops_type(:id), do: integer()
  defp ecto_type_to_drops_type(:binary_id), do: string()

  # Binary types
  defp ecto_type_to_drops_type(:binary), do: string()
  defp ecto_type_to_drops_type(:bitstring), do: string()

  # Date and time types - now using proper Drops types
  defp ecto_type_to_drops_type(:date), do: type(:date)
  defp ecto_type_to_drops_type(:time), do: type(:time)
  defp ecto_type_to_drops_type(:time_usec), do: type(:time)
  defp ecto_type_to_drops_type(:naive_datetime), do: type(:date_time)
  defp ecto_type_to_drops_type(:naive_datetime_usec), do: type(:date_time)
  defp ecto_type_to_drops_type(:utc_datetime), do: type(:date_time)
  defp ecto_type_to_drops_type(:utc_datetime_usec), do: type(:date_time)

  # Duration type (Elixir 1.17+)
  defp ecto_type_to_drops_type(:duration), do: any()

  # Decimal type - using number() for better validation than any()
  defp ecto_type_to_drops_type(:decimal), do: number()

  # Handle array types
  defp ecto_type_to_drops_type({:array, inner_type}) do
    list(ecto_type_to_drops_type(inner_type), [])
  end

  # Handle map types
  defp ecto_type_to_drops_type(:map), do: map()
  defp ecto_type_to_drops_type({:map, _}), do: map()

  # Fallback for unknown types
  defp ecto_type_to_drops_type(_), do: any()
end
