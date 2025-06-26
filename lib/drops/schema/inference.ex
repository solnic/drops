defprotocol Drops.Schema.Inference do
  @moduledoc """
  Protocol for inferring Drops schemas from arbitrary input types.

  This protocol allows for extensible schema inference from different sources
  such as Map structs, Ecto schemas, JSON schemas, or any other data structure
  that can be converted into a Drops schema.

  ## Examples

      # Infer from a Map struct (uses existing compiler)
      schema_map = %{
        required(:name) => string(),
        required(:age) => integer()
      }
      Drops.Schema.Inference.infer_schema(schema_map, [])

      # Infer from an Ecto schema
      Drops.Schema.Inference.infer_schema(MyApp.User, [])

  ## Implementation

  Each implementation should return a schema AST that can be processed by
  `Drops.Type.Compiler.visit/2` to create the final type structure.

  The returned schema should be in the format expected by the compiler:
  - Map schemas: `%{required(:field) => type_spec, ...}`
  - Other formats as appropriate for the input type

  ## Compiler Integration

  Implementations can optionally provide their own compiler by implementing
  the `Drops.Schema.Compiler` protocol for the same type. If no custom
  compiler is provided, the default `Drops.Type.Compiler` will be used.
  """

  @doc """
  Infer a schema from the given input.

  ## Parameters

  - `input` - The input to infer a schema from (Map, Ecto schema module, etc.)
  - `opts` - Options to pass to the schema inference and compilation

  ## Returns

  Returns a schema AST that can be processed by `Drops.Type.Compiler.visit/2`.
  """
  @spec infer_schema(any(), keyword()) :: any()
  def infer_schema(input, opts)
end
