defmodule Drops.Schema.Inference.EctoTest do
  use Drops.ContractCase

  alias Drops.Schema.Inference
  import Drops.Type.DSL

  describe "Ecto schema inference" do
    test "infers schema from Ecto schema module" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.UserSchema, [])

      expected = %{
        required(:name) => string(),
        required(:email) => string()
      }

      assert result == expected
    end

    test "respects exclude_fields option" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.UserSchema, exclude_fields: [:email])

      expected = %{
        required(:name) => string()
      }

      assert result == expected
    end

    test "respects field_presence option" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.UserSchema,
          field_presence: %{name: :required, email: :optional}
        )

      expected = %{
        required(:name) => string(),
        optional(:email) => string()
      }

      assert result == expected
    end

    test "respects default_presence option" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.UserSchema,
          default_presence: :optional
        )

      expected = %{
        optional(:name) => string(),
        optional(:email) => string()
      }

      assert result == expected
    end

    test "includes all fields when exclude_fields is empty" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.UserSchema, exclude_fields: [])

      # Should include id, inserted_at, updated_at fields
      assert Map.has_key?(result, required(:id))
      assert Map.has_key?(result, required(:inserted_at))
      assert Map.has_key?(result, required(:updated_at))
      assert Map.has_key?(result, required(:name))
      assert Map.has_key?(result, required(:email))
    end

    test "raises error for non-Ecto schema modules" do
      assert_raise ArgumentError, ~r/Cannot infer schema from atom/, fn ->
        Inference.infer_schema(NonExistentModule, [])
      end
    end

    test "raises error for non-schema atoms" do
      assert_raise ArgumentError, ~r/not an Ecto schema module/, fn ->
        Inference.infer_schema(String, [])
      end
    end
  end

  describe "Basic primitive types inference" do
    test "infers basic primitive types correctly" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.BasicTypesSchema, [])

      expected = %{
        required(:string_field) => string(),
        required(:integer_field) => integer(),
        required(:float_field) => float(),
        required(:boolean_field) => boolean(),
        required(:binary_field) => string(),
        required(:bitstring_field) => string()
      }

      assert result == expected
    end
  end

  describe "ID types inference" do
    test "infers ID types correctly" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.IdTypesSchema, [])

      expected = %{
        required(:id_field) => integer(),
        required(:binary_id_field) => string()
      }

      assert result == expected
    end
  end

  describe "Date and time types inference" do
    test "infers date and time types correctly" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.DateTimeTypesSchema, [])

      expected = %{
        required(:date_field) => type(:date),
        required(:time_field) => type(:time),
        required(:time_usec_field) => type(:time),
        required(:naive_datetime_field) => type(:date_time),
        required(:naive_datetime_usec_field) => type(:date_time),
        required(:utc_datetime_field) => type(:date_time),
        required(:utc_datetime_usec_field) => type(:date_time)
      }

      assert result == expected
    end
  end

  describe "Numeric types inference" do
    test "infers numeric types correctly" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.NumericTypesSchema, [])

      expected = %{
        required(:decimal_field) => number(),
        required(:integer_field) => integer(),
        required(:float_field) => float()
      }

      assert result == expected
    end
  end

  describe "Array types inference" do
    test "infers array types correctly" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.ArrayTypesSchema, [])

      expected = %{
        required(:string_array) => list(string(), []),
        required(:integer_array) => list(integer(), []),
        required(:float_array) => list(float(), []),
        required(:boolean_array) => list(boolean(), []),
        required(:date_array) => list(type(:date), [])
      }

      assert result == expected
    end
  end

  describe "Map types inference" do
    test "infers map types correctly" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.MapTypesSchema, [])

      expected = %{
        required(:map_field) => map(),
        required(:typed_map_field) => map()
      }

      assert result == expected
    end
  end

  describe "Virtual fields handling" do
    test "excludes virtual fields by default" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.VirtualFieldsSchema, [])

      expected = %{
        required(:name) => string()
      }

      assert result == expected
      refute Map.has_key?(result, required(:computed_value))
      refute Map.has_key?(result, required(:any_virtual))
    end
  end

  describe "Timestamps handling" do
    test "excludes timestamp fields by default" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.TimestampsSchema, [])

      expected = %{
        required(:name) => string()
      }

      assert result == expected
      refute Map.has_key?(result, required(:inserted_at))
      refute Map.has_key?(result, required(:updated_at))
    end

    test "includes timestamp fields when explicitly requested" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.TimestampsSchema, exclude_fields: [])

      assert Map.has_key?(result, required(:id))
      assert Map.has_key?(result, required(:name))
      assert Map.has_key?(result, required(:inserted_at))
      assert Map.has_key?(result, required(:updated_at))
    end
  end

  describe "Primary key handling" do
    test "excludes default primary key by default" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.TimestampsSchema, [])

      refute Map.has_key?(result, required(:id))
    end

    test "handles custom primary key" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.CustomPrimaryKeySchema,
          exclude_fields: []
        )

      assert Map.has_key?(result, required(:uuid))
      assert Map.has_key?(result, required(:name))
    end

    test "handles schema without primary key" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.NoPrimaryKeySchema, [])

      expected = %{
        required(:name) => string(),
        required(:value) => integer()
      }

      assert result == expected
    end

    test "handles composite primary key" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.CompositePrimaryKeySchema,
          exclude_fields: []
        )

      expected = %{
        required(:part1) => string(),
        required(:part2) => integer(),
        required(:data) => string()
      }

      assert result == expected
    end
  end

  describe "Custom types handling" do
    test "handles Ecto.UUID and Ecto.Enum as any() type" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.CustomTypesSchema, [])

      expected = %{
        required(:uuid_field) => any(),
        required(:enum_field) => any()
      }

      assert result == expected
    end
  end

  describe "Associations handling" do
    test "excludes associations but includes foreign keys" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.AssociationsSchema, [])

      expected = %{
        required(:name) => string(),
        required(:parent_id) => integer()
      }

      assert result == expected
      # Association fields themselves are not included
      refute Map.has_key?(result, required(:items))
      refute Map.has_key?(result, required(:parent))
    end
  end

  describe "Embedded schemas handling" do
    test "handles embedded schemas correctly" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.EmbeddedTypesSchema, [])

      expected = %{
        required(:name) => string(),
        required(:value) => integer()
      }

      assert result == expected
    end

    test "embedded schemas work with field presence options" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.EmbeddedTypesSchema,
          field_presence: %{name: :required, value: :optional}
        )

      expected = %{
        required(:name) => string(),
        optional(:value) => integer()
      }

      assert result == expected
    end
  end

  describe "Edge cases and error handling" do
    test "handles empty schema gracefully" do
      # Create a minimal schema for testing
      defmodule EmptyTestSchema do
        use Ecto.Schema

        schema "empty" do
        end
      end

      result = Inference.infer_schema(EmptyTestSchema, [])
      assert result == %{}
    end

    test "handles schema with only excluded fields" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.BasicTypesSchema,
          exclude_fields: [
            :string_field,
            :integer_field,
            :float_field,
            :boolean_field,
            :binary_field,
            :bitstring_field
          ]
        )

      assert result == %{}
    end

    test "handles unknown field types gracefully" do
      # This test ensures that unknown types fall back to any()
      # The implementation should handle this via the fallback clause
      result = Inference.infer_schema(Test.Ecto.TestSchemas.CustomTypesSchema, [])

      # Custom types should map to any()
      assert Map.get(result, required(:uuid_field)) == any()
      assert Map.get(result, required(:enum_field)) == any()
    end
  end

  describe "Casting support" do
    test "generates casting schema when cast: true" do
      result = Inference.infer_schema(Test.Ecto.TestSchemas.CastingTestSchema, cast: true)

      # Check that all fields are EctoCaster types
      name_spec = Map.get(result, required(:name))
      admin_spec = Map.get(result, required(:admin))
      age_spec = Map.get(result, required(:age))
      score_spec = Map.get(result, required(:score))

      # Verify structure: EctoCaster types
      assert %Drops.Types.EctoCaster{} = name_spec
      assert %Drops.Types.EctoCaster{} = admin_spec
      assert %Drops.Types.EctoCaster{} = age_spec
      assert %Drops.Types.EctoCaster{} = score_spec

      # Verify ecto_type and ecto_schema are set correctly
      assert name_spec.ecto_type == :string
      assert name_spec.ecto_schema == Test.Ecto.TestSchemas.CastingTestSchema

      assert admin_spec.ecto_type == :boolean
      assert admin_spec.ecto_schema == Test.Ecto.TestSchemas.CastingTestSchema

      assert age_spec.ecto_type == :integer
      assert age_spec.ecto_schema == Test.Ecto.TestSchemas.CastingTestSchema

      assert score_spec.ecto_type == :float
      assert score_spec.ecto_schema == Test.Ecto.TestSchemas.CastingTestSchema
    end

    test "casting works with field presence options" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.CastingTestSchema,
          cast: true,
          field_presence: %{admin: :optional, age: :optional},
          default_presence: :required
        )

      # Check that presence is respected
      assert Map.has_key?(result, required(:name))
      assert Map.has_key?(result, required(:score))
      assert Map.has_key?(result, optional(:admin))
      assert Map.has_key?(result, optional(:age))
    end

    test "casting works with exclude_fields option" do
      result =
        Inference.infer_schema(Test.Ecto.TestSchemas.CastingTestSchema,
          cast: true,
          exclude_fields: [:age, :score]
        )

      # Only name and admin should be present
      assert Map.has_key?(result, required(:name))
      assert Map.has_key?(result, required(:admin))
      refute Map.has_key?(result, required(:age))
      refute Map.has_key?(result, required(:score))
    end

    test "EctoCaster validates and casts correctly" do
      alias Drops.Type.Validator

      # Test boolean casting
      caster =
        Drops.Types.EctoCaster.new(:boolean, Test.Ecto.TestSchemas.CastingTestSchema)

      assert {:ok, true} = Validator.validate(caster, "true")
      assert {:ok, false} = Validator.validate(caster, "false")

      # Test integer casting
      caster =
        Drops.Types.EctoCaster.new(:integer, Test.Ecto.TestSchemas.CastingTestSchema)

      assert {:ok, 42} = Validator.validate(caster, "42")

      # Test float casting
      caster = Drops.Types.EctoCaster.new(:float, Test.Ecto.TestSchemas.CastingTestSchema)

      assert {:ok, 3.14} = Validator.validate(caster, "3.14")
    end

    test "EctoCaster returns error for invalid values" do
      alias Drops.Type.Validator

      # Test invalid boolean value
      caster =
        Drops.Types.EctoCaster.new(:boolean, Test.Ecto.TestSchemas.CastingTestSchema)

      assert {:error, {:cast, [predicate: :cast, args: ["has unexpected value"]]}} =
               Validator.validate(caster, "invalid")

      # Test invalid integer value
      caster =
        Drops.Types.EctoCaster.new(:integer, Test.Ecto.TestSchemas.CastingTestSchema)

      assert {:error, {:cast, [predicate: :cast, args: ["has unexpected value"]]}} =
               Validator.validate(caster, "not_a_number")
    end

    test "casting schema validates and casts values correctly" do
      # Create and compile a casting schema
      compiled_schema =
        Drops.Schema.infer_and_compile(Test.Ecto.TestSchemas.CastingTestSchema,
          cast: true,
          field_presence: %{admin: :optional, age: :optional, score: :optional},
          default_presence: :required
        )

      # Test successful casting
      input = %{
        name: "John Doe",
        admin: "true",
        age: "25",
        score: "95.5"
      }

      assert {:ok, {:map, results}} =
               Drops.Type.Validator.validate(compiled_schema, input)

      # Extract the actual values from the validation results
      result =
        Enum.reduce(results, %{}, fn
          {:ok, {[key], value}}, acc -> Map.put(acc, key, value)
          _, acc -> acc
        end)

      assert result == %{
               name: "John Doe",
               admin: true,
               age: 25,
               score: 95.5
             }

      # Test with boolean false
      input2 = %{
        name: "Jane Doe",
        admin: "false"
      }

      assert {:ok, {:map, results2}} =
               Drops.Type.Validator.validate(compiled_schema, input2)

      result2 =
        Enum.reduce(results2, %{}, fn
          {:ok, {[key], value}}, acc -> Map.put(acc, key, value)
          _, acc -> acc
        end)

      assert result2 == %{
               name: "Jane Doe",
               admin: false
             }

      # Test with different number formats
      input3 = %{
        name: "Bob Smith",
        age: "0",
        score: "0.0"
      }

      assert {:ok, {:map, results3}} =
               Drops.Type.Validator.validate(compiled_schema, input3)

      result3 =
        Enum.reduce(results3, %{}, fn
          {:ok, {[key], value}}, acc -> Map.put(acc, key, value)
          _, acc -> acc
        end)

      assert result3 == %{
               name: "Bob Smith",
               age: 0,
               score: 0.0
             }
    end

    test "casting schema handles validation errors correctly" do
      # Create and compile a casting schema
      compiled_schema =
        Drops.Schema.infer_and_compile(Test.Ecto.TestSchemas.CastingTestSchema,
          cast: true,
          field_presence: %{admin: :optional, age: :optional, score: :optional},
          default_presence: :required
        )

      # Test invalid boolean value
      input = %{
        name: "John Doe",
        admin: "maybe"
      }

      assert {:error, {:map, results}} =
               Drops.Type.Validator.validate(compiled_schema, input)

      # Find the error for admin field
      admin_error =
        Enum.find(results, fn
          {:error, {[:admin], _}} -> true
          _ -> false
        end)

      assert admin_error != nil
      {:error, {[:admin], cast_error}} = admin_error
      # The error should be related to casting failure
      assert {:cast, error_details} = cast_error
      assert error_details[:predicate] == :cast
      assert error_details[:args] != nil

      # Test invalid integer value
      input2 = %{
        name: "Jane Doe",
        age: "not_a_number"
      }

      assert {:error, {:map, results2}} =
               Drops.Type.Validator.validate(compiled_schema, input2)

      # Find the error for age field
      age_error =
        Enum.find(results2, fn
          {:error, {[:age], _}} -> true
          _ -> false
        end)

      assert age_error != nil
      {:error, {[:age], cast_error2}} = age_error
      # The error should be related to casting failure
      assert {:cast, error_details2} = cast_error2
      assert error_details2[:predicate] == :cast
      assert error_details2[:args] != nil

      # Test missing required field
      input3 = %{
        admin: "true"
      }

      assert {:error, {:map, results3}} =
               Drops.Type.Validator.validate(compiled_schema, input3)

      # Find the error for missing name field
      name_error =
        Enum.find(results3, fn
          {:error, {[:name], _}} -> true
          _ -> false
        end)

      assert name_error != nil
      {:error, {[:name], error_details3}} = name_error
      # The error should be related to missing key
      assert error_details3[:predicate] == :has_key?
    end
  end
end
