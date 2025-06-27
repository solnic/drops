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
end
