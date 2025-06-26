defimpl Drops.Schema.Inference, for: Map do
  @moduledoc """
  Schema inference implementation for Map structs.

  This implementation handles the inference of schemas from Map structs
  that contain Drops schema definitions. It simply returns the map as-is
  since it's already in the correct format for the default compiler.

  ## Examples

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

  ## Validation

  This implementation assumes the map is already a valid Drops schema
  definition. No validation is performed on the structure.
  """

  @doc """
  Infer schema from a Map struct.

  Since Map structs are already in the correct format for Drops schemas,
  this implementation simply returns the input map unchanged.

  ## Parameters

  - `map` - A Map containing Drops schema definitions
  - `opts` - Options (currently unused for Map inference)

  ## Returns

  Returns the input map unchanged.
  """
  def infer_schema(map, _opts) when is_map(map) do
    map
  end
end
