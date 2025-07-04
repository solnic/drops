defmodule Drops.OperationsTest do
  use Drops.OperationCase, async: true

  describe "defining shared functions" do
    test "imports functions from a base module" do
      defmodule Test.Operations do
        use Drops.Operations.Command

        def build_user do
          %{name: "Jane Doe"}
        end
      end

      defmodule Test.CreateUser do
        use Test.Operations

        import Test.Operations, only: [build_user: 0]

        steps do
          @impl true
          def execute(%{params: _params}) do
            {:ok, build_user()}
          end
        end
      end

      {:ok, result} = Test.CreateUser.call(%{params: %{}})
      assert result == %{name: "Jane Doe"}
    end

    test "inherits steps from source module" do
      defmodule Test.BaseOperationWithSteps do
        use Drops.Operations.Command

        steps do
          def custom_step(context) do
            {:ok, Map.put(context, :custom_step_called, true)}
          end

          def helper_step(context) do
            {:ok, Map.put(context, :helper_called, true)}
          end
        end
      end

      defmodule Test.DerivedOperation do
        use Test.BaseOperationWithSteps

        steps do
          @impl true
          def execute(context) do
            # Call the inherited custom_step and helper_step
            {:ok, result1} = custom_step(context)
            {:ok, result2} = helper_step(result1)
            {:ok, Map.put(result2, :derived_execute_called, true)}
          end
        end
      end

      {:ok, result} = Test.DerivedOperation.call(%{params: %{}})

      assert result.custom_step_called == true
      assert result.helper_called == true
      assert result.derived_execute_called == true
    end
  end

  describe "basic operations" do
    operation :command do
      steps do
        @impl true
        def execute(%{params: params}) do
          if params[:name] == nil do
            {:error, "name is required"}
          else
            {:ok, params}
          end
        end
      end
    end

    test "it works without schema", %{operation: operation} do
      {:ok, result} = operation.call(%{params: %{name: "Jane Doe"}})

      assert result == %{name: "Jane Doe"}
    end
  end

  describe "operations with schema" do
    operation :command do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      steps do
        @impl true
        def execute(%{params: params}) do
          if params[:name] != "Jane Doe" do
            {:error, "name is not expected"}
          else
            {:ok, params}
          end
        end
      end
    end

    test "it works with a schema", %{operation: operation} do
      {:ok, result} = operation.call(%{params: %{name: "Jane Doe"}})

      assert result == %{name: "Jane Doe"}

      {:error, result} = operation.call(%{params: %{name: ""}})

      assert_errors(["name must be filled"], {:error, result})
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

      steps do
        @impl true
        def prepare(%{params: %{template: true} = params} = context) do
          updated_params = Map.put(params, :name, params.name <> ".template")
          {:ok, Map.put(context, :params, updated_params)}
        end

        @impl true
        def execute(%{params: params}) do
          {:ok, params}
        end
      end
    end

    test "passes prepared params to execute", %{operation: operation} do
      {:ok, result} = operation.call(%{params: %{name: "README.md", template: true}})

      assert result == %{name: "README.md.template", template: true}
    end
  end

  describe "composing multiple operations" do
    operation name: :create_user, type: :command do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      steps do
        @impl true
        def execute(%{params: params}) do
          {:ok, Map.merge(params, %{id: :rand.uniform(1000)})}
        end
      end
    end

    operation name: :update_user, type: :command do
      schema do
        %{
          required(:name) => string(:filled?)
        }
      end

      steps do
        @impl true
        def execute(%{execute_result: user, params: params}) do
          {:ok, Map.merge(user, params)}
        end
      end
    end

    test "can safely compose multiple operations", %{
      create_user: create_op,
      update_user: update_op
    } do
      result =
        create_op.call(%{params: %{name: "Jane"}})
        |> update_op.call(%{params: %{name: "Jane Doe"}})

      # Check the structure and that the ID is preserved from the first operation
      assert {:ok, %{id: id, name: "Jane Doe"}} = result

      assert is_integer(id) and id > 0

      result =
        create_op.call(%{params: %{name: ""}})
        |> update_op.call(%{params: %{name: "Jane Doe"}})

      assert {:error, _error} = result

      result =
        create_op.call(%{params: %{name: "Jane"}})
        |> update_op.call(%{params: %{name: ""}})

      assert {:error, _error} = result
    end
  end
end
