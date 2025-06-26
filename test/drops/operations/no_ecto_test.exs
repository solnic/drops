defmodule Drops.Operations.NoEctoTest do
  use ExUnit.Case, async: true

  describe "Operations without Ecto" do
    defmodule NoEctoOperations do
      use Drops.Operations
    end

    defmodule SimpleCommand do
      use NoEctoOperations, type: :command

      schema do
        %{
          required(:name) => string(),
          optional(:age) => integer()
        }
      end

      @impl true
      def execute(%{params: params}) do
        if params.name == "error" do
          {:error, "Name cannot be 'error'"}
        else
          {:ok, "Hello, #{params.name}!"}
        end
      end

      @impl true
      def execute(previous_result, %{params: params}) do
        if params.name == "compose" do
          {:ok, "#{previous_result} + #{params.name}"}
        else
          {:error, "Composition failed"}
        end
      end
    end

    defmodule SimpleQuery do
      use NoEctoOperations, type: :query

      schema do
        %{
          required(:id) => integer()
        }
      end

      @impl true
      def execute(%{params: params}) do
        if params.id < 0 do
          {:error, "ID must be positive"}
        else
          {:ok, %{id: params.id, name: "User #{params.id}"}}
        end
      end

      @impl true
      def execute(previous_result, %{params: params}) do
        if params.id == 999 do
          {:ok, Map.put(previous_result, :updated_id, params.id)}
        else
          {:error, "Query composition failed"}
        end
      end
    end

    test "command operations work without Ecto" do
      params = %{name: "Alice", age: 30}

      assert {:ok, result} = SimpleCommand.call(params)
      assert result.result == "Hello, Alice!"
      assert result.params == %{name: "Alice", age: 30}
      assert result.operation == SimpleCommand
    end

    test "query operations work without Ecto" do
      params = %{id: 123}

      assert {:ok, result} = SimpleQuery.call(params)
      assert result.result == %{id: 123, name: "User 123"}
      assert result.params == %{id: 123}
      assert result.operation == SimpleQuery
    end

    test "validation works without Ecto" do
      # Missing required field
      params = %{age: 30}

      assert {:error, failure} = SimpleCommand.call(params)
      assert failure.operation == SimpleCommand
      assert failure.params == params

      # Should have validation errors
      assert is_list(failure.result)
      assert length(failure.result) > 0
    end

    test "operations don't have Ecto-specific functions when no repo configured" do
      # These functions should not be available
      refute function_exported?(SimpleCommand, :changeset, 1)
      refute function_exported?(SimpleCommand, :cast_changeset, 2)
      refute function_exported?(SimpleCommand, :persist, 1)

      # But these should be available
      assert function_exported?(SimpleCommand, :call, 1)
      assert function_exported?(SimpleCommand, :execute, 1)
      assert function_exported?(SimpleCommand, :prepare, 1)
    end

    test "schema validation works correctly without Ecto" do
      # Valid params
      valid_params = %{name: "Bob", age: 25}
      assert {:ok, _result} = SimpleCommand.call(valid_params)

      # Invalid type
      invalid_params = %{name: "Bob", age: "not_an_integer"}
      assert {:error, failure} = SimpleCommand.call(invalid_params)
      assert is_list(failure.result)
    end

    test "prepare function works without Ecto" do
      defmodule CommandWithPrepare do
        use NoEctoOperations, type: :command

        schema do
          %{
            required(:name) => string()
          }
        end

        def prepare(%{params: params} = context) do
          updated_params = Map.put(params, :prepared, true)
          Map.put(context, :params, updated_params)
        end

        @impl true
        def execute(%{params: params}) do
          {:ok, params}
        end
      end

      params = %{name: "Alice"}
      assert {:ok, result} = CommandWithPrepare.call(params)
      assert result.params.prepared == true
    end

    test "command execute can return errors" do
      params = %{name: "error"}
      assert {:error, failure} = SimpleCommand.call(params)
      assert failure.result == "Name cannot be 'error'"
      assert failure.operation == SimpleCommand
    end

    test "query execute can return errors" do
      params = %{id: -1}
      assert {:error, failure} = SimpleQuery.call(params)
      assert failure.result == "ID must be positive"
      assert failure.operation == SimpleQuery
    end

    test "operations support composition with success path" do
      # Test successful composition for command
      initial_result = {:ok, %Drops.Operations.Success{result: "Initial"}}
      params = %{name: "compose"}
      assert {:ok, result} = SimpleCommand.call(initial_result, params)
      assert result.result == "Initial + compose"

      # Test successful composition for query
      initial_result = {:ok, %Drops.Operations.Success{result: %{id: 1, name: "Test"}}}
      params = %{id: 999}
      assert {:ok, result} = SimpleQuery.call(initial_result, params)
      assert result.result.updated_id == 999
    end
  end

  describe "Form operations without Ecto" do
    defmodule NoEctoFormOperations do
      use Drops.Operations
    end

    defmodule SimpleForm do
      use NoEctoFormOperations, type: :form

      schema do
        %{
          required(:email) => string(),
          optional(:name) => string()
        }
      end

      @impl true
      def execute(%{params: params}) do
        if params.email == "invalid@test.com" do
          {:error, "Invalid email address"}
        else
          {:ok, "Form submitted with #{params.email}"}
        end
      end

      @impl true
      def execute(previous_result, %{params: params}) do
        if params.email == "compose@test.com" do
          {:ok, "#{previous_result} + composed"}
        else
          {:error, "Form composition failed"}
        end
      end
    end

    test "form operations work without Ecto" do
      # Test with string keys (typical form input)
      params = %{"email" => "test@example.com", "name" => "Test User"}

      assert {:ok, result} = SimpleForm.call(params)
      assert result.result == "Form submitted with test@example.com"
      assert result.type == :form

      # Params should be converted to atom keys due to atomize: true
      assert result.params.email == "test@example.com"
      assert result.params.name == "Test User"
    end

    test "form validation works without Ecto" do
      # Missing required field
      params = %{"name" => "Test User"}

      assert {:error, failure} = SimpleForm.call(params)
      assert failure.type == :form
      assert is_list(failure.result)
    end

    test "form execute can return errors" do
      params = %{"email" => "invalid@test.com", "name" => "Test User"}
      assert {:error, failure} = SimpleForm.call(params)
      assert failure.result == "Invalid email address"
      assert failure.operation == SimpleForm
    end

    test "form operations support composition" do
      # Test successful composition
      initial_result = {:ok, %Drops.Operations.Success{result: "Initial form"}}
      params = %{"email" => "compose@test.com", "name" => "Test"}

      assert {:ok, %Drops.Operations.Success{result: result}} =
               SimpleForm.call(initial_result, params)

      assert result == "Initial form + composed"

      # Test failed composition
      initial_result = {:ok, %Drops.Operations.Success{result: "Initial form"}}
      params = %{"email" => "other@test.com", "name" => "Test"}
      assert {:error, result} = SimpleForm.call(initial_result, params)
      assert result.operation == SimpleForm
    end
  end
end
