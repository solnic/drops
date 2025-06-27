defmodule Drops.SchemaTest do
  use Drops.ContractCase

  alias Drops.Schema
  import Drops.Type.DSL

  describe "compile_schema/3" do
    test "compiles schema AST using default compiler" do
      schema_ast = %{
        required(:name) => string(),
        required(:age) => integer()
      }

      result = Schema.compile_schema(%{}, schema_ast, [])

      assert %Drops.Types.Map{} = result
      assert length(result.keys) == 2
    end

    test "falls back to default compiler when no custom compiler exists" do
      schema_ast = %{required(:test) => string()}

      result = Schema.compile_schema("some_string", schema_ast, [])

      assert %Drops.Types.Map{} = result
      assert length(result.keys) == 1
    end
  end

  describe "has_custom_compiler?/1" do
    test "returns false for types without custom compilers" do
      refute Schema.has_custom_compiler?(%{})
      refute Schema.has_custom_compiler?("string")
      refute Schema.has_custom_compiler?(123)
    end
  end
end
