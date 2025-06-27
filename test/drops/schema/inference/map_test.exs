defmodule Drops.Schema.InferenceTest do
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

      expected =
        {:map,
         [
           {required(:age), type(:integer)},
           {required(:name), type(:string)}
         ]}

      assert result == expected
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

      expected =
        {:map,
         [
           {required(:company), type(:string)},
           {required(:user),
            {:map,
             [
               {required(:age), type(:integer)},
               {required(:name), type(:string)}
             ]}}
         ]}

      assert result == expected
    end

    test "handles mixed atom and non-atom values" do
      plain_map = %{
        name: :string,
        count: :integer,
        data: %{nested: :boolean}
      }

      result = Inference.infer_schema(plain_map, [])

      expected =
        {:map,
         [
           {required(:count), type(:integer)},
           {required(:data),
            {:map,
             [
               {required(:nested), type(:boolean)}
             ]}},
           {required(:name), type(:string)}
         ]}

      assert result == expected
    end

    test "does not convert maps that already have schema keys" do
      mixed_map = %{
        required(:name) => string(),
        optional(:age) => integer()
      }

      result = Inference.infer_schema(mixed_map, [])

      # Should return unchanged since it already has schema keys
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

      expected =
        {:map,
         [
           {required(:level1),
            {:map,
             [
               {required(:level2),
                {:map,
                 [
                   {required(:level3), type(:string)}
                 ]}}
             ]}}
         ]}

      assert result == expected
    end
  end

  describe "Map inference - integration with schema compilation" do
    test "plain map can be compiled and used for validation" do
      plain_map = %{name: :string, age: :integer}

      # Test that the inferred schema can be compiled
      compiled_type = Drops.Schema.infer_and_compile(plain_map, [])

      assert %Drops.Types.Map{} = compiled_type
      assert length(compiled_type.keys) == 2

      # Test that the compiled type structure is correct
      key_names = Enum.map(compiled_type.keys, & &1.path) |> Enum.sort()
      assert key_names == [[:age], [:name]]

      # Test that all keys are required by default
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

      # Check that the nested structure is properly compiled
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
      # Test with custom type as value
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

      expected =
        {:map,
         [
           {required(:email), CustomEmail},
           {required(:user), CustomUser}
         ]}

      assert result == expected
    end

    test "does not treat regular modules as Drops types" do
      # Test with regular Elixir modules that have structs
      plain_map = %{
        date: Date,
        process: Process,
        string_module: String
      }

      result = Inference.infer_schema(plain_map, [])

      # These should be treated as module type specs, not custom Drops types
      assert {:map, key_specs} = result

      # Convert to a map for easier comparison (order doesn't matter)
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

      # Test successful validation with custom types
      valid_input = %{
        email: "test@example.com",
        user: %{name: "John", email: "john@example.com"}
      }

      assert {:ok, result} = TestCustomTypeContract.conform(valid_input)
      assert result == valid_input

      # Test validation failure
      invalid_input = %{
        # Should fail CustomEmail validation (filled?)
        email: "",
        user: %{name: "John", email: "john@example.com"}
      }

      assert {:error, errors} = TestCustomTypeContract.conform(invalid_input)
      assert length(errors) > 0
    end
  end
end
