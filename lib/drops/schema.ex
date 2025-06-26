defmodule Drops.Schema do
  @moduledoc """
  Main module for schema inference and compilation.

  This module provides the primary interface for inferring schemas from
  arbitrary input types and compiling them into Drops type structures.

  ## Usage

      # Infer and compile a Map schema
      schema_map = %{
        required(:name) => string(),
        required(:age) => integer()
      }
      type = Drops.Schema.infer_and_compile(schema_map, [])

      # Infer and compile an Ecto schema
      type = Drops.Schema.infer_and_compile(MyApp.User, [])

  ## Protocol-based Architecture

  This module uses two protocols for extensibility:

  1. `Drops.Schema.Inference` - For inferring schema AST from input
  2. `Drops.Schema.Compiler` - For custom compilation logic (optional)

  If no custom compiler is implemented for a type, the default
  `Drops.Type.Compiler` is used.
  """

  alias Drops.Schema.Inference
  alias Drops.Schema.Compiler
  alias Drops.Type.Compiler, as: DefaultCompiler

  @doc """
  Infer a schema from input and compile it into a Drops type structure.

  This is the main entry point for schema inference and compilation.

  ## Parameters

  - `input` - The input to infer a schema from
  - `opts` - Options to pass to inference and compilation

  ## Returns

  Returns a compiled Drops type structure ready for validation.

  ## Examples

      # Map schema
      schema = %{required(:name) => string()}
      type = Drops.Schema.infer_and_compile(schema, [])

      # Ecto schema
      type = Drops.Schema.infer_and_compile(MyApp.User, [])
  """
  @spec infer_and_compile(any(), keyword()) :: struct()
  def infer_and_compile(input, opts \\ []) do
    schema_ast = Inference.infer_schema(input, opts)
    compile_schema(input, schema_ast, opts)
  end

  @doc """
  Compile a schema AST using the appropriate compiler.

  This function attempts to use a custom compiler via the `Drops.Schema.Compiler`
  protocol. If no implementation exists, it falls back to the default compiler.

  ## Parameters

  - `input` - The original input used for inference
  - `schema_ast` - The schema AST to compile
  - `opts` - Compilation options

  ## Returns

  Returns a compiled Drops type structure.
  """
  @spec compile_schema(any(), any(), keyword()) :: struct()
  def compile_schema(input, schema_ast, opts) do
    try do
      Compiler.compile(input, schema_ast, opts)
    rescue
      Protocol.UndefinedError ->
        DefaultCompiler.visit(schema_ast, opts)
    end
  end

  @doc """
  Check if a custom compiler is available for the given input type.

  ## Parameters

  - `input` - The input to check

  ## Returns

  Returns `true` if a custom compiler is available, `false` otherwise.
  """
  @spec has_custom_compiler?(any()) :: boolean()
  def has_custom_compiler?(input) do
    try do
      Compiler.compile(input, nil, [])
      true
    rescue
      Protocol.UndefinedError -> false
      _ -> true  # Other errors mean implementation exists but failed
    end
  end
end
