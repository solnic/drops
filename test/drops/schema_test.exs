defmodule Drops.SchemaTest do
  use Drops.ContractCase

  alias Drops.Schema
  import Drops.Type.DSL

  describe "Ecto schema inference and compilation" do
    test "infers and compiles Ecto schema with default options" do
      result = Schema.infer_and_compile(Test.Ecto.UserSchema, [])

      # Should return a compiled Drops.Types.Map struct
      assert %Drops.Types.Map{} = result
      assert length(result.keys) == 2

      # Check that the keys are properly compiled
      name_key = Enum.find(result.keys, &(&1.path == [:name]))
      email_key = Enum.find(result.keys, &(&1.path == [:email]))

      assert name_key.presence == :required
      assert email_key.presence == :required
      assert %Drops.Types.Primitive{primitive: :string} = name_key.type
      assert %Drops.Types.Primitive{primitive: :string} = email_key.type
    end

    test "stores Ecto schema module in meta field" do
      result = Schema.infer_and_compile(Test.Ecto.UserSchema, [])

      # Should return a compiled Drops.Types.Map struct with meta information
      assert %Drops.Types.Map{meta: meta} = result
      assert meta[:source_schema] == Test.Ecto.UserSchema
    end

    test "preserves existing meta when adding source schema" do
      existing_meta = %{custom_key: "custom_value"}
      result = Schema.infer_and_compile(Test.Ecto.UserSchema, meta: existing_meta)

      # Should preserve existing meta and add source schema
      assert %Drops.Types.Map{meta: meta} = result
      assert meta[:source_schema] == Test.Ecto.UserSchema
      assert meta[:custom_key] == "custom_value"
    end

    test "meta field works with different Ecto schemas" do
      # Test with a different schema
      result = Schema.infer_and_compile(Test.Ecto.TestSchemas.BasicTypesSchema, [])

      assert %Drops.Types.Map{meta: meta} = result
      assert meta[:source_schema] == Test.Ecto.TestSchemas.BasicTypesSchema
    end

    test "non-Ecto atoms do not get source_schema in meta" do
      # Test with a regular map (should not have source_schema)
      schema_map = %{
        required(:name) => string(),
        required(:age) => integer()
      }

      result = Schema.infer_and_compile(schema_map, [])

      assert %Drops.Types.Map{meta: meta} = result
      refute Map.has_key?(meta, :source_schema)
    end

    test "respects field presence options" do
      result =
        Schema.infer_and_compile(Test.Ecto.UserSchema,
          field_presence: %{name: :required},
          default_presence: :optional
        )

      # Check that options were applied
      name_key = Enum.find(result.keys, &(&1.path == [:name]))
      email_key = Enum.find(result.keys, &(&1.path == [:email]))

      assert name_key.presence == :required
      assert email_key.presence == :optional
    end

    test "respects exclude_fields option" do
      result = Schema.infer_and_compile(Test.Ecto.UserSchema, exclude_fields: [:email])

      # Should exclude email AND the default fields (id, inserted_at, updated_at)
      assert length(result.keys) == 1
      name_key = Enum.find(result.keys, &(&1.path == [:name]))
      assert name_key != nil

      email_key = Enum.find(result.keys, &(&1.path == [:email]))
      assert email_key == nil
    end

    test "includes timestamp fields when not excluded" do
      result = Schema.infer_and_compile(Test.Ecto.UserSchema, exclude_fields: [])

      # Should include id, inserted_at, updated_at fields
      id_key = Enum.find(result.keys, &(&1.path == [:id]))
      inserted_at_key = Enum.find(result.keys, &(&1.path == [:inserted_at]))
      updated_at_key = Enum.find(result.keys, &(&1.path == [:updated_at]))

      assert id_key != nil
      assert inserted_at_key != nil
      assert updated_at_key != nil
      # id, name, email, inserted_at, updated_at
      assert length(result.keys) == 5
    end
  end

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
      # Use a type that doesn't have a custom compiler
      schema_ast = %{required(:test) => string()}

      result = Schema.compile_schema("some_string", schema_ast, [])

      assert %Drops.Types.Map{} = result
      assert length(result.keys) == 1
    end
  end

  describe "error handling" do
    test "raises error for non-Ecto schema modules" do
      assert_raise ArgumentError, ~r/Cannot infer schema from atom/, fn ->
        Schema.infer_and_compile(NonExistentModule, [])
      end
    end

    test "raises error for non-schema atoms" do
      assert_raise ArgumentError, ~r/not an Ecto schema module/, fn ->
        Schema.infer_and_compile(String, [])
      end
    end
  end

  describe "has_custom_compiler?/1" do
    test "returns false for types without custom compilers" do
      refute Schema.has_custom_compiler?(%{})
      refute Schema.has_custom_compiler?("string")
      refute Schema.has_custom_compiler?(123)
    end

    test "returns true for Ecto schema modules (which have custom compilers)" do
      assert Schema.has_custom_compiler?(Test.Ecto.UserSchema)
    end
  end
end
