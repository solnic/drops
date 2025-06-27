defimpl Drops.Schema.Inference, for: Map do
  @moduledoc """
  Schema inference implementation for Map structs.

  This implementation handles the inference of schemas from Map structs
  that contain either Drops schema definitions or plain key-value pairs.

  ## Examples

      # Already formatted Drops schema (unchanged)
      schema_map = %{
        required(:name) => string(),
        required(:age) => integer(),
        optional(:email) => string()
      }

      # Returns the same map
      Drops.Schema.Inference.infer_schema(schema_map, [])
      #=> %{
      #     required(:name) => string(),
      #     required(:age) => integer(),
      #     optional(:email) => string()
      #   }

      # Plain map (converted to AST)
      plain_map = %{name: :string, age: :integer}

      # Converts to proper AST format
      Drops.Schema.Inference.infer_schema(plain_map, [])
      #=> %{
      #     required(:name) => type(:string),
      #     required(:age) => type(:integer)
      #   }

  ## Conversion Rules

  For plain maps:
  - Map keys are converted to `required(key)` AST nodes
  - Map values are converted to `type(value)` AST nodes
  - Nested maps are processed recursively

  ## Validation

  This implementation assumes the map is either already a valid Drops schema
  definition or a plain map that can be converted. No validation is performed
  on the structure.
  """

  @doc """
  Infer schema from a Map struct.

  This function handles two cases:
  1. Maps that are already in Drops schema format (returned unchanged)
  2. Plain maps that need conversion to Drops schema AST format

  ## Parameters

  - `map` - A Map containing either Drops schema definitions or plain key-value pairs
  - `opts` - Options (currently unused for Map inference)

  ## Returns

  Returns either the input map unchanged (if already in schema format) or
  a converted map with proper AST nodes.
  """
  def infer_schema(map, opts) when is_map(map) do
    cond do
      # If it's a struct (compiled type), return as-is
      is_struct(map) ->
        map

      # If it's a plain map, convert it
      is_plain_map?(map) ->
        convert_plain_map(map, opts)

      # Otherwise, it's already a schema definition
      true ->
        map
    end
  end

  defp is_plain_map?(map) when map_size(map) == 0, do: false

  defp is_plain_map?(map) do
    map
    |> Enum.all?(fn {key, _value} ->
      not is_schema_key?(key)
    end)
  end

  defp is_schema_key?({:required, _}), do: true
  defp is_schema_key?({:optional, _}), do: true
  defp is_schema_key?(_), do: false

  defp convert_plain_map(map, opts) do
    key_specs =
      map
      |> Map.keys()
      |> Enum.map(fn key ->
        value = Map.get(map, key)
        schema_key = {:required, key}
        schema_value = convert_value(value, opts)
        {schema_key, schema_value}
      end)

    {:map, key_specs}
  end

  defp convert_value(value, opts) when is_map(value) do
    infer_schema(value, opts)
  end

  defp convert_value({:type, _} = value, _opts) do
    value
  end

  defp convert_value({:union, _} = value, _opts) do
    value
  end

  defp convert_value({:cast, _} = value, _opts) do
    value
  end

  defp convert_value(value, _opts) when is_atom(value) and value != nil do
    if is_drops_type?(value) do
      value
    else
      {:type, {value, []}}
    end
  end

  defp convert_value(value, _opts) do
    {:type, {value, []}}
  end

  # Check if a value is a custom Drops.Type module
  defp is_drops_type?(value) when is_atom(value) do
    # Use the new Type registry for reliable detection
    Drops.Type.type?(value)
  end

  defp is_drops_type?(_), do: false
end
