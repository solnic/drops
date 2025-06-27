defmodule Drops.Schema.Inference.MapTest do
  use Drops.ContractCase

  alias Drops.Schema.Inference
  import Drops.Type.DSL

  describe "Map inference - existing schema format" do
    test "infers schema from a simple map" do
      schema_map = %{
        required(:name) => string(),
        required(:age) => integer()
      }

      result = Inference.infer_schema(schema_map, [])

      assert result == schema_map
    end

    test "infers schema from a complex map" do
      schema_map = %{
        required(:name) => string(:filled?),
        optional(:email) => string(),
        required(:address) => %{
          required(:street) => string(),
          required(:city) => string(),
          optional(:zipcode) => string()
        }
      }

      result = Inference.infer_schema(schema_map, [])

      assert result == schema_map
    end

    test "handles empty map" do
      schema_map = %{}

      result = Inference.infer_schema(schema_map, [])

      assert result == %{}
    end
  end

  describe "Map inference - plain map conversion" do
    test "converts simple plain map to schema AST" do
      plain_map = %{name: :string, age: :integer}

      result = Inference.infer_schema(plain_map, [])

      assert {:map, key_specs} = result
      assert length(key_specs) == 2

      result_map = Map.new(key_specs)

      expected_map = %{
        required(:age) => type(:integer),
        required(:name) => type(:string)
      }

      assert result_map == expected_map
    end

    test "converts nested plain maps to schema AST" do
      plain_map = %{
        user: %{
          name: :string,
          age: :integer
        },
        company: :string
      }

      result = Inference.infer_schema(plain_map, [])

      assert {:map, key_specs} = result
      assert length(key_specs) == 2

      result_map = Map.new(key_specs)

      assert Map.has_key?(result_map, required(:company))
      assert Map.has_key?(result_map, required(:user))

      assert result_map[required(:company)] == type(:string)

      assert {:map, user_key_specs} = result_map[required(:user)]
      user_map = Map.new(user_key_specs)

      expected_user_map = %{
        required(:age) => type(:integer),
        required(:name) => type(:string)
      }

      assert user_map == expected_user_map
    end

    test "handles mixed atom and non-atom values" do
      plain_map = %{
        name: :string,
        count: :integer,
        data: %{nested: :boolean}
      }

      result = Inference.infer_schema(plain_map, [])

      assert {:map, key_specs} = result
      assert length(key_specs) == 3

      result_map = Map.new(key_specs)

      assert result_map[required(:name)] == type(:string)
      assert result_map[required(:count)] == type(:integer)

      assert {:map, data_key_specs} = result_map[required(:data)]
      data_map = Map.new(data_key_specs)
      expected_data_map = %{required(:nested) => type(:boolean)}
      assert data_map == expected_data_map
    end

    test "does not convert maps that already have schema keys" do
      mixed_map = %{
        required(:name) => string(),
        optional(:age) => integer()
      }

      result = Inference.infer_schema(mixed_map, [])

      assert result == mixed_map
    end

    test "handles deeply nested plain maps" do
      plain_map = %{
        level1: %{
          level2: %{
            level3: :string
          }
        }
      }

      result = Inference.infer_schema(plain_map, [])

      assert {:map, key_specs} = result
      assert length(key_specs) == 1

      [{level1_key, level1_spec}] = key_specs
      assert level1_key == required(:level1)
      assert {:map, level2_specs} = level1_spec
      assert length(level2_specs) == 1

      [{level2_key, level2_spec}] = level2_specs
      assert level2_key == required(:level2)
      assert {:map, level3_specs} = level2_spec
      assert length(level3_specs) == 1

      [{level3_key, level3_spec}] = level3_specs
      assert level3_key == required(:level3)
      assert level3_spec == type(:string)
    end
  end

  describe "Map inference - integration with schema compilation" do
    test "plain map can be compiled and used for validation" do
      plain_map = %{name: :string, age: :integer}

      compiled_type = Drops.Schema.infer_and_compile(plain_map, [])

      assert %Drops.Types.Map{} = compiled_type
      assert length(compiled_type.keys) == 2

      key_names = Enum.map(compiled_type.keys, & &1.path) |> Enum.sort()
      assert key_names == [[:age], [:name]]

      presences = Enum.map(compiled_type.keys, & &1.presence) |> Enum.uniq()
      assert presences == [:required]
    end

    test "nested plain map can be compiled and used for validation" do
      plain_map = %{
        user: %{
          name: :string,
          age: :integer
        }
      }

      compiled_type = Drops.Schema.infer_and_compile(plain_map, [])

      assert %Drops.Types.Map{} = compiled_type
      assert length(compiled_type.keys) == 1

      [user_key] = compiled_type.keys
      assert user_key.path == [:user]
      assert user_key.presence == :required
      assert %Drops.Types.Map{} = user_key.type
      assert length(user_key.type.keys) == 2
    end
  end

  describe "Custom Drops type detection" do
    defmodule CustomEmail do
      use Drops.Type, string(:filled?)
    end

    defmodule CustomUser do
      use Drops.Type, %{
        required(:name) => string(),
        required(:email) => string()
      }
    end

    test "correctly identifies custom Drops types in plain maps" do
      plain_map = %{email: CustomEmail}

      result = Inference.infer_schema(plain_map, [])

      expected = {:map, [{required(:email), CustomEmail}]}

      assert result == expected
    end

    test "correctly identifies custom Drops types in nested maps" do
      plain_map = %{
        user: CustomUser,
        email: CustomEmail
      }

      result = Inference.infer_schema(plain_map, [])

      assert {:map, key_specs} = result
      assert length(key_specs) == 2

      result_map = Map.new(key_specs)

      expected_map = %{
        required(:email) => CustomEmail,
        required(:user) => CustomUser
      }

      assert result_map == expected_map
    end

    test "does not treat regular modules as Drops types" do
      plain_map = %{
        date: Date,
        process: Process,
        string_module: String
      }

      result = Inference.infer_schema(plain_map, [])

      assert {:map, key_specs} = result

      result_map = Map.new(key_specs)

      expected_map = %{
        required(:date) => {:type, {Date, []}},
        required(:process) => {:type, {Process, []}},
        required(:string_module) => {:type, {String, []}}
      }

      assert result_map == expected_map
    end

    test "custom types work end-to-end in contracts" do
      defmodule TestCustomTypeContract do
        use Drops.Contract

        schema do
          %{
            email: CustomEmail,
            user: CustomUser
          }
        end
      end

      valid_input = %{
        email: "test@example.com",
        user: %{name: "John", email: "john@example.com"}
      }

      assert {:ok, result} = TestCustomTypeContract.conform(valid_input)
      assert result == valid_input

      invalid_input = %{
        email: "",
        user: %{name: "John", email: "john@example.com"}
      }

      assert {:error, errors} = TestCustomTypeContract.conform(invalid_input)
      assert length(errors) > 0
    end
  end
end
