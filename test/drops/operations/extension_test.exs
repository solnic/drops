defmodule Drops.Operations.ExtensionTest do
  use Drops.OperationCase, async: false

  defmodule Test.Extensions do
    defmodule PrepareExtension do
      use Drops.Operations.Extension

      @impl true
      def using do
        quote do
          def prepare(%{params: params} = context) do
            updated_params =
              if Map.has_key?(params, :name) do
                Map.put(params, :name, "prepared_" <> params.name)
              else
                params
              end

            {:ok, Map.put(context, :params, updated_params)}
          end

          def prepare_more(%{params: params} = context) do
            {:ok, Map.put(context, :params, Map.put(params, :prepared, true))}
          end
        end
      end

      @impl true
      def unit_of_work(uow, _opts) do
        after_step(uow, :prepare, :prepare_more)
      end
    end

    defmodule ValidateExtension do
      use Drops.Operations.Extension

      @impl true
      def using do
        quote do
          def validate(%{params: params} = context) do
            if Map.has_key?(params, :name) and String.contains?(params.name, "invalid") do
              {:error, "name cannot contain 'invalid'"}
            else
              {:ok, context}
            end
          end
        end
      end
    end

    defmodule StepExtension do
      use Drops.Operations.Extension

      @impl true
      def using do
        quote do
          def log_before_prepare(context) do
            Process.put(:before_prepare_called, true)
            {:ok, Map.put(context, :before_prepare_called, true)}
          end

          def log_after_prepare(context) do
            {:ok, Map.put(context, :after_prepare_called, true)}
          end
        end
      end

      @impl true
      def unit_of_work(uow, _opts) do
        uow
        |> before_step(:prepare, :log_before_prepare)
        |> after_step(:prepare, :log_after_prepare)
      end
    end
  end

  alias Test.Extensions, as: Exts

  describe "extension registration" do
    test "operations inherit extensions from base module" do
      defmodule Test.MyOperationsWithExtensions do
        use Drops.Operations
      end

      defmodule Test.MyOperation do
        use Test.MyOperationsWithExtensions,
          type: :command,
          extensions: [Exts.PrepareExtension]

        steps do
          def execute(context) do
            {:ok, context}
          end
        end
      end

      assert Drops.Operations.Extensions.Params in Test.MyOperationsWithExtensions.__extensions__()

      assert Exts.PrepareExtension in Test.MyOperation.__enabled_extensions__()
    end
  end

  describe "extension behavior verification" do
    test "PrepareExtension modifies params in prepare step" do
      defmodule Test.PrepareOperations do
        use Drops.Operations, extensions: [Exts.PrepareExtension]
      end

      defmodule Test.PrepareOperation do
        use Test.PrepareOperations

        schema do
          %{
            required(:name) => string()
          }
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, params}
          end
        end
      end

      {:ok, result} = Test.PrepareOperation.call(%{params: %{name: "test"}})
      assert result == %{name: "prepared_test", prepared: true}
    end

    test "ValidateExtension adds custom validation" do
      defmodule Test.ValidateOperations do
        use Drops.Operations, extensions: [Exts.ValidateExtension]
      end

      defmodule Test.ValidateOperation do
        use Test.ValidateOperations

        schema do
          %{
            required(:name) => string()
          }
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, params}
          end
        end
      end

      {:ok, result} = Test.ValidateOperation.call(%{params: %{name: "valid_name"}})
      assert result == %{name: "valid_name"}

      {:error, error} = Test.ValidateOperation.call(%{params: %{name: "invalid_name"}})
      assert error == "name cannot contain 'invalid'"
    end

    test "multiple extensions work together" do
      defmodule Test.MultiExtensionOperations do
        use Drops.Operations, extensions: [Exts.PrepareExtension, Exts.ValidateExtension]
      end

      defmodule Test.MultiExtensionOperation do
        use Test.MultiExtensionOperations

        schema do
          %{
            required(:name) => string()
          }
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, params}
          end
        end
      end

      {:ok, result} = Test.MultiExtensionOperation.call(%{params: %{name: "test"}})
      assert result == %{name: "prepared_test", prepared: true}

      {:error, error} = Test.MultiExtensionOperation.call(%{params: %{name: "invalid"}})
      assert error == "name cannot contain 'invalid'"
    end

    test "StepExtension adds steps before and after prepare" do
      defmodule Test.StepOperations do
        use Drops.Operations, extensions: [Exts.StepExtension]
      end

      defmodule Test.StepOperation do
        use Test.StepOperations

        schema do
          %{
            required(:name) => string()
          }
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, params}
          end
        end
      end

      # Check that steps are added to the UnitOfWork
      uow = Test.StepOperation.__unit_of_work__()

      # Verify log_before_prepare step is added before prepare
      prepare_index = Enum.find_index(uow.step_order, &(&1 == :prepare))
      before_index = Enum.find_index(uow.step_order, &(&1 == :log_before_prepare))

      assert before_index == prepare_index - 1
      assert uow.steps[:log_before_prepare] == {Test.StepOperation, :log_before_prepare}

      # Verify log_after_prepare step is added after prepare
      after_index = Enum.find_index(uow.step_order, &(&1 == :log_after_prepare))
      assert after_index == prepare_index + 1
      assert uow.steps[:log_after_prepare] == {Test.StepOperation, :log_after_prepare}
    end

    test "StepExtension demonstrates step execution order" do
      defmodule Test.StepTestOperations do
        use Drops.Operations, extensions: [Exts.StepExtension]
      end

      defmodule Test.StepTestOperation do
        use Test.StepTestOperations

        schema do
          %{
            required(:data) => string()
          }
        end

        steps do
          @impl true
          def execute(context) do
            # Return the full context so we can verify the step markers
            {:ok, context}
          end
        end
      end

      # Test actual execution to verify steps work
      context = %{params: %{data: "test"}}
      {:ok, result} = Test.StepTestOperation.call(context)

      # Verify both before and after steps were executed
      assert result.before_prepare_called == true
      assert result.after_prepare_called == true
    end
  end
end
