defprotocol Drops.Schema.Compiler do
  @moduledoc """
  Protocol for compiling inferred schemas into Drops type structures.

  This protocol allows for custom compilation logic for different input types.
  If no implementation is provided for a type, the default `Drops.Type.Compiler`
  will be used.

  ## Examples

      # Custom compiler for Ecto schemas
      defimpl Drops.Schema.Compiler, for: Atom do
        def compile(ecto_schema_module, schema_ast, opts) when is_atom(ecto_schema_module) do
          # Custom compilation logic for Ecto schemas
          Drops.Schema.EctoCompiler.compile(schema_ast, opts)
        end
      end

  ## Integration

  This protocol is used by `Drops.Schema.infer_and_compile/2` to allow
  custom compilation steps for specific input types while falling back
  to the default compiler for others.
  """

  @doc """
  Compile a schema AST into a Drops type structure.

  ## Parameters

  - `input` - The original input that was used for inference
  - `schema_ast` - The schema AST returned by `Drops.Schema.Inference.infer_schema/2`
  - `opts` - Options to pass to the compilation

  ## Returns

  Returns a compiled Drops type structure that can be used for validation.
  """
  @spec compile(any(), any(), keyword()) :: struct()
  def compile(input, schema_ast, opts)
end
