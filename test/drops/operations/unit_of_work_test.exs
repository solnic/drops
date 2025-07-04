defmodule Drops.Operations.UnitOfWorkTest do
  use Drops.OperationCase, async: true

  alias Drops.Operations.UnitOfWork

  # Helper function to create UnitOfWork with default steps
  defp new_uow(
         module,
         steps \\ [:conform, :prepare, :validate, :execute]
       ) do
    UnitOfWork.new(module, steps)
  end

  describe "new/2" do
    test "creates a UnitOfWork with default steps" do
      defmodule TestOperation do
        def schema, do: %{keys: []}
        def __operation_type__, do: :command
      end

      uow = new_uow(TestOperation)

      assert uow.module == TestOperation
      assert uow.steps[:conform] == {TestOperation, :conform}
      assert uow.steps[:prepare] == {TestOperation, :prepare}
      assert uow.steps[:validate] == {TestOperation, :validate}
      assert uow.steps[:execute] == {TestOperation, :execute}
    end

    test "creates UnitOfWork without any default callbacks" do
      defmodule TestOperation do
        def schema, do: %{keys: []}
        def __operation_type__, do: :command
      end

      uow = new_uow(TestOperation)

      assert uow.callbacks.after == %{}
      assert uow.callbacks.before == %{}
    end
  end

  describe "step ordering" do
    test "after_step/3 executes new step after existing step" do
      test_pid = self()

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}

          def prepare(context) do
            send(context.test_pid, {:step, :prepare})
            {:ok, context}
          end

          def audit(context) do
            send(context.test_pid, {:step, :audit})
            {:ok, context}
          end

          def validate(context), do: {:ok, context}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      uow = TestOperation.__unit_of_work__()
      updated_uow = UnitOfWork.after_step(uow, :prepare, :audit)

      context = %{params: %{}, test_pid: test_pid}
      UnitOfWork.process(updated_uow, context)

      # Verify audit step was executed after prepare
      assert_receive {:step, :prepare}
      assert_receive {:step, :audit}
    end

    test "after_step/3 raises when existing step not found" do
      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(context) do
            {:ok, context}
          end

          def audit(context) do
            {:ok, context}
          end
        end
      end

      uow = TestOperation.__unit_of_work__()

      assert_raise RuntimeError,
                   "Existing step nonexistent not found in UnitOfWork",
                   fn ->
                     UnitOfWork.after_step(uow, :nonexistent, :audit)
                   end
    end

    test "before_step/3 executes new step before existing step" do
      test_pid = self()

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          def audit(context) do
            send(context.test_pid, {:step, :audit})
            {:ok, context}
          end

          @impl true
          def execute(context) do
            send(context.test_pid, {:step, :execute})
            {:ok, context}
          end
        end
      end

      uow = TestOperation.__unit_of_work__()
      updated_uow = UnitOfWork.before_step(uow, :execute, :audit)

      context = %{params: %{}, test_pid: test_pid}
      UnitOfWork.process(updated_uow, context)

      # Verify audit step was executed before execute
      assert_receive {:step, :audit}
      assert_receive {:step, :execute}
    end

    test "before_step/3 raises when existing step not found" do
      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def audit(context) do
            {:ok, context}
          end

          def conform(context) do
            {:ok, context}
          end

          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      uow = TestOperation.__unit_of_work__()

      assert_raise RuntimeError,
                   "Existing step nonexistent not found in UnitOfWork",
                   fn ->
                     UnitOfWork.before_step(uow, :nonexistent, :audit)
                   end
    end
  end

  describe "before callbacks" do
    test "executes before callbacks with correct parameters" do
      # Create a test module to capture callback invocations
      test_pid = self()

      defmodule BeforeCallbackModule do
        def test_callback(module, step, context, config) do
          send(
            config.test_pid,
            {:before_callback, module, step, context, config}
          )
        end
      end

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      uow = TestOperation.__unit_of_work__()
      config = %{test_pid: test_pid, key: "value"}

      updated_uow =
        UnitOfWork.register_before_callback(
          uow,
          :prepare,
          BeforeCallbackModule,
          :test_callback,
          config
        )

      context = %{params: %{name: "test"}}
      UnitOfWork.process(updated_uow, context)

      # Verify the callback was called with correct parameters
      assert_receive {:before_callback, TestOperation, :prepare, ^context, ^config}
    end

    test "executes multiple before callbacks in registration order" do
      test_pid = self()

      defmodule BeforeCallbackModule1 do
        def callback1(module, step, _context, config) do
          send(config.test_pid, {:callback1, module, step})
        end
      end

      defmodule BeforeCallbackModule2 do
        def callback2(module, step, _context, config) do
          send(config.test_pid, {:callback2, module, step})
        end
      end

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      uow = TestOperation.__unit_of_work__()
      config = %{test_pid: test_pid}

      updated_uow =
        uow
        |> UnitOfWork.register_before_callback(
          :prepare,
          BeforeCallbackModule1,
          :callback1,
          config
        )
        |> UnitOfWork.register_before_callback(
          :prepare,
          BeforeCallbackModule2,
          :callback2,
          config
        )

      context = %{params: %{}}
      UnitOfWork.process(updated_uow, context)

      # Verify callbacks were called in reverse registration order (LIFO)
      assert_receive {:callback2, TestOperation, :prepare}
      assert_receive {:callback1, TestOperation, :prepare}
    end

    test "callbacks receive correct module parameter" do
      test_pid = self()

      defmodule CallbackModule do
        def test_callback(module, step, _context, config) do
          send(config.test_pid, {:callback_called, module, step})
        end
      end

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      uow = TestOperation.__unit_of_work__()
      config = %{test_pid: test_pid}

      updated_uow =
        UnitOfWork.register_before_callback(
          uow,
          :prepare,
          CallbackModule,
          :test_callback,
          config
        )

      context = %{params: %{}}
      UnitOfWork.process(updated_uow, context)

      # Verify callback received the correct operation module
      assert_receive {:callback_called, TestOperation, :prepare}
    end
  end

  describe "after callbacks" do
    test "executes after callbacks with correct parameters" do
      test_pid = self()

      defmodule AfterCallbackModule do
        def test_callback(module, step, context, result, config) do
          send(
            config.test_pid,
            {:after_callback, module, step, context, result, config}
          )
        end
      end

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, Map.put(context, :prepared, true)}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      uow = TestOperation.__unit_of_work__()
      config = %{test_pid: test_pid, key: "value"}

      updated_uow =
        UnitOfWork.register_after_callback(
          uow,
          :prepare,
          AfterCallbackModule,
          :test_callback,
          config
        )

      context = %{params: %{name: "test"}}
      UnitOfWork.process(updated_uow, context)

      # Verify the callback was called with correct parameters
      expected_result = {:ok, %{params: %{name: "test"}, prepared: true}}

      assert_receive {:after_callback, TestOperation, :prepare, ^context,
                      ^expected_result, ^config}
    end

    test "executes multiple after callbacks in registration order" do
      test_pid = self()

      defmodule AfterCallbackModule1 do
        def callback1(module, step, _context, _result, config) do
          send(config.test_pid, {:callback1, module, step})
        end
      end

      defmodule AfterCallbackModule2 do
        def callback2(module, step, _context, _result, config) do
          send(config.test_pid, {:callback2, module, step})
        end
      end

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      uow = TestOperation.__unit_of_work__()
      config = %{test_pid: test_pid}

      updated_uow =
        uow
        |> UnitOfWork.register_after_callback(
          :prepare,
          AfterCallbackModule1,
          :callback1,
          config
        )
        |> UnitOfWork.register_after_callback(
          :prepare,
          AfterCallbackModule2,
          :callback2,
          config
        )

      context = %{params: %{}}
      UnitOfWork.process(updated_uow, context)

      # Verify callbacks were called in reverse registration order (LIFO)
      assert_receive {:callback2, TestOperation, :prepare}
      assert_receive {:callback1, TestOperation, :prepare}
    end

    test "callbacks work correctly with step execution order" do
      test_pid = self()

      defmodule CallbackModule do
        def before_prepare(_module, step, context, config) do
          send(config.test_pid, {:before, step, context})
        end

        def after_prepare(_module, step, context, result, config) do
          send(config.test_pid, {:after, step, context, result})
        end

        def before_execute(_module, step, context, config) do
          send(config.test_pid, {:before, step, context})
        end

        def after_execute(_module, step, context, result, config) do
          send(config.test_pid, {:after, step, context, result})
        end
      end

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}

          def prepare(context) do
            send(context.test_pid, {:step, :prepare, context})
            {:ok, Map.put(context, :prepared, true)}
          end

          def validate(context), do: {:ok, context}

          @impl true
          def execute(context) do
            send(context.test_pid, {:step, :execute, context})
            {:ok, Map.put(context, :executed, true)}
          end
        end
      end

      uow = TestOperation.__unit_of_work__()
      config = %{test_pid: test_pid}

      updated_uow =
        uow
        |> UnitOfWork.register_before_callback(
          :prepare,
          CallbackModule,
          :before_prepare,
          config
        )
        |> UnitOfWork.register_after_callback(
          :prepare,
          CallbackModule,
          :after_prepare,
          config
        )
        |> UnitOfWork.register_before_callback(
          :execute,
          CallbackModule,
          :before_execute,
          config
        )
        |> UnitOfWork.register_after_callback(
          :execute,
          CallbackModule,
          :after_execute,
          config
        )

      context = %{params: %{name: "test"}, test_pid: test_pid}
      UnitOfWork.process(updated_uow, context)

      # Verify execution order: before -> step -> after for each step
      assert_receive {:before, :prepare, ^context}
      assert_receive {:step, :prepare, ^context}

      prepared_context = %{params: %{name: "test"}, test_pid: test_pid, prepared: true}
      expected_prepare_result = {:ok, prepared_context}
      assert_receive {:after, :prepare, ^context, ^expected_prepare_result}

      assert_receive {:before, :execute, ^prepared_context}
      assert_receive {:step, :execute, ^prepared_context}

      executed_context = %{
        params: %{name: "test"},
        test_pid: test_pid,
        prepared: true,
        executed: true
      }

      expected_execute_result = {:ok, executed_context}
      assert_receive {:after, :execute, ^prepared_context, ^expected_execute_result}
    end

    test "after callbacks are not called when step fails" do
      test_pid = self()

      defmodule CallbackModule do
        def before_validate(_module, step, _context, config) do
          send(config.test_pid, {:before, step})
        end

        def after_validate(_module, step, _context, _result, config) do
          send(config.test_pid, {:after, step})
        end
      end

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(_context), do: {:error, "validation failed"}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      uow = TestOperation.__unit_of_work__()
      config = %{test_pid: test_pid}

      updated_uow =
        uow
        |> UnitOfWork.register_before_callback(
          :validate,
          CallbackModule,
          :before_validate,
          config
        )
        |> UnitOfWork.register_after_callback(
          :validate,
          CallbackModule,
          :after_validate,
          config
        )

      context = %{params: %{}}
      {:error, _} = UnitOfWork.process(updated_uow, context)

      # Verify before callback was called but after callback was not
      assert_receive {:before, :validate}
      refute_receive {:after, :validate}
    end
  end

  describe "override_step/4" do
    test "executes overridden step instead of default" do
      test_pid = self()

      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}

          def prepare(context) do
            send(context.test_pid, {:step, :original_prepare})
            {:ok, context}
          end

          def validate(context), do: {:ok, context}

          @impl true
          def execute(context), do: {:ok, context}
        end
      end

      defmodule CustomModule do
        def custom_prepare(context) do
          send(context.test_pid, {:step, :custom_prepare})
          {:ok, Map.put(context, :custom, true)}
        end
      end

      uow = TestOperation.__unit_of_work__()
      updated_uow = UnitOfWork.override_step(uow, :prepare, CustomModule, :custom_prepare)

      context = %{params: %{}, test_pid: test_pid}
      {:ok, result} = UnitOfWork.process(updated_uow, context)

      # Verify custom step was executed instead of original
      assert_receive {:step, :custom_prepare}
      refute_receive {:step, :original_prepare}

      # Verify custom step modified the context
      assert result.custom == true
    end
  end

  describe "process/2" do
    operation do
      schema do
        %{
          required(:name) => string()
        }
      end

      steps do
        @impl true
        def execute(%{params: params}) do
          {:ok, Map.put(params, :processed, true)}
        end
      end
    end

    test "processes through full pipeline", %{operation: operation} do
      uow = operation.__unit_of_work__()
      context = %{params: %{name: "test"}}

      {:ok, result} = UnitOfWork.process(uow, context)

      assert result == %{name: "test", processed: true}
    end

    test "processes without adding module to context" do
      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

          @impl true
          def execute(context) do
            # Verify module is NOT in context
            refute Map.has_key?(context, :module)
            {:ok, context}
          end
        end
      end

      uow = TestOperation.__unit_of_work__()
      context = %{params: %{}}

      {:ok, _result} = UnitOfWork.process(uow, context)
    end

    test "handles errors in pipeline" do
      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperation do
        use TestOperations

        steps do
          def conform(context), do: {:ok, context}
          def prepare(context), do: {:ok, context}
          def validate(_context), do: {:error, "validation failed"}

          @impl true
          def execute(_context), do: {:ok, %{}}
        end
      end

      uow = TestOperation.__unit_of_work__()
      context = %{params: %{}}

      {:error, error} = UnitOfWork.process(uow, context)
      assert error == "validation failed"
    end

    test "processes correctly without conform step" do
      defmodule TestOperations do
        use Drops.Operations, type: :command
      end

      defmodule TestOperationNoConform do
        use TestOperations

        steps do
          def prepare(context), do: {:ok, context}
          def validate(context), do: {:ok, context}

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

      uow = TestOperationNoConform.__unit_of_work__()
      context = %{params: %{name: "Jane Doe"}}

      {:ok, result} = UnitOfWork.process(uow, context)
      assert result == %{name: "Jane Doe"}
    end
  end
end
