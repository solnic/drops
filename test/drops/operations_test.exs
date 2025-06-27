defmodule Drops.OperationsTest do
  use Drops.OperationCase, async: true

  describe "defining shared functions" do
    test "imports functions from a base module" do
      defmodule Test.Operations do
        use Drops.Operations, type: :command

        def build_user do
          %{name: "Jane Doe"}
        end
      end

      defmodule Test.CreateUser do
        use Test.Operations

        @impl true
        def execute(%{params: _params}) do
          {:ok, build_user()}
        end
      end

      {:ok, %{type: :command, result: result}} = Test.CreateUser.call(%{})
      assert result == %{name: "Jane Doe"}
    end
  end

  describe "basic operations" do
    operation :command do
      @impl true
      def execute(%{params: params}) do
        if params[:name] == nil do
          {:error, "name is required"}
        else
          {:ok, params}
        end
      end
    end

    test "it works without schema", %{operation: operation} do
      {:ok, %{result: result, params: params}} = operation.call(%{name: "Jane Doe"})

      assert result == %{name: "Jane Doe"}
      assert params == %{name: "Jane Doe"}
    end
  end

  describe "operations with schema" do
    operation :command do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      @impl true
      def execute(%{params: params}) do
        if params[:name] != "Jane Doe" do
          {:error, "name is not expected"}
        else
          {:ok, params}
        end
      end
    end

    test "it works with a schema", %{operation: operation} do
      {:ok, %{result: result, params: params}} =
        operation.call(%{name: "Jane Doe"})

      assert result == %{name: "Jane Doe"}
      assert params == %{name: "Jane Doe"}

      {:error, %{result: result, params: params}} =
        operation.call(%{name: ""})

      assert_errors(["name must be filled"], {:error, result})
      assert params == %{name: ""}
    end
  end

  describe "using prepare/1" do
    operation :command do
      schema do
        %{
          required(:name) => string(:filled?),
          required(:template) => boolean()
        }
      end

      @impl true
      def prepare(%{params: %{template: true} = params} = context) do
        updated_params = Map.put(params, :name, params.name <> ".template")
        Map.put(context, :params, updated_params)
      end

      @impl true
      def execute(%{params: params}) do
        {:ok, params}
      end
    end

    test "passes prepared params to execute", %{operation: operation} do
      {:ok, %{result: result, params: params}} =
        operation.call(%{name: "README.md", template: true})

      assert result == %{name: "README.md.template", template: true}
      assert params == %{name: "README.md.template", template: true}
    end
  end

  describe "composing multiple operations" do
    operation name: :create_user, type: :command do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      @impl true
      def execute(%{params: params}) do
        {:ok, Map.merge(params, %{id: :rand.uniform(1000)})}
      end
    end

    operation name: :update_user, type: :command do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      @impl true
      def execute(user, %{params: params}) do
        {:ok, Map.merge(user, params)}
      end
    end

    test "can safely compose multiple operations", %{
      create_user: create_op,
      update_user: update_op
    } do
      result = create_op.call(%{name: "Jane"}) |> update_op.call(%{name: "Jane Doe"})

      # Check the structure and that the ID is preserved from the first operation
      assert {:ok,
              %Drops.Operations.Success{
                operation: ^update_op,
                result: %{id: id, name: "Jane Doe"}
              }} = result

      assert is_integer(id) and id > 0

      result = create_op.call(%{name: ""}) |> update_op.call(%{name: "Jane Doe"})
      assert {:error, %Drops.Operations.Failure{}} = result

      result = create_op.call(%{name: "Jane"}) |> update_op.call(%{name: ""})
      assert {:error, %Drops.Operations.Failure{}} = result
    end
  end
end
