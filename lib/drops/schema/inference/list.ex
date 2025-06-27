defimpl Drops.Schema.Inference, for: List do
  @moduledoc """
  Schema inference implementation for List structs.

  This implementation handles the inference of schemas from List structs
  that contain either already compiled Drops types (for unions) or other
  schema definitions.

  ## Examples

      # List of compiled types (union)
      compiled_types = [
        %Drops.Types.Map{...},
        %Drops.Types.Map{...}
      ]

      # Returns a union of the types
      Drops.Schema.Inference.infer_schema(compiled_types, [])
      #=> [left_type, right_type]

      # List of schema definitions
      schema_list = [
        %{required(:name) => string()},
        %{required(:login) => string()}
      ]

      # Returns a union of the schema definitions
      Drops.Schema.Inference.infer_schema(schema_list, [])
      #=> [left_schema, right_schema]

  ## Conversion Rules

  For lists:
  - If the list contains exactly 2 elements, they are treated as a union
  - If elements are already compiled types, they are returned as-is
  - If elements are schema definitions, they are processed recursively
  - Lists with other lengths are passed through unchanged

  ## Validation

  This implementation assumes the list contains valid schema definitions
  or compiled types. No validation is performed on the structure.
  """

  alias Drops.Schema.Inference

  @doc """
  Infer schema from a List.

  This function handles lists that represent unions of schemas or types.
  The most common case is a two-element list representing a union.

  ## Parameters

  - `list` - A List containing schema definitions or compiled types
  - `opts` - Options to pass to recursive inference calls

  ## Returns

  Returns a list that can be processed by `Drops.Type.Compiler.visit/2`
  to create a union type.
  """
  def infer_schema(list, opts) when is_list(list) do
    case list do
      # Two-element list - check if elements need inference
      [left, right] ->
        [infer_element(left, opts), infer_element(right, opts)]

      # Other cases - pass through unchanged for now
      # This allows the compiler to handle other list formats
      _ ->
        list
    end
  end

  # Helper function to infer individual elements
  defp infer_element(element, opts) do
    cond do
      # Already a compiled type - return as-is
      is_struct(element) ->
        element

      # Schema definition - infer recursively
      true ->
        Inference.infer_schema(element, opts)
    end
  end
end
