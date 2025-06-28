defmodule Drops.Operations.ExtensionTest do
  use Drops.OperationCase, async: false

  alias Drops.Operations.Extension

  # Ensure test extensions are compiled and available
  Code.require_file("test/support/test_extension.ex")
  Code.require_file("test/support/manual_extension.ex")

  alias Test.Support.{TestExtension, ManualExtension}

  describe "extension registration" do
    test "registered_extensions/0 handles application not started" do
      # Temporarily clear the persistent term to simulate app not started
      original_config = :persistent_term.get({:drops_config, :registered_extensions}, [])
      :persistent_term.erase({:drops_config, :registered_extensions})

      # Should fallback to app env when persistent term not available
      # Built-in extensions should be available from app env
      extensions = Extension.registered_extensions()
      assert Drops.Operations.Extensions.Ecto in extensions

      # Restore the original config
      :persistent_term.put({:drops_config, :registered_extensions}, original_config)
    end

    test "Operations module can be defined when application not started" do
      # Temporarily clear the persistent term to simulate app not started
      original_config = :persistent_term.get({:drops_config, :registered_extensions}, [])
      :persistent_term.erase({:drops_config, :registered_extensions})

      # This should not raise an error during compilation
      defmodule TestOperationWithoutApp do
        use Drops.Operations, repo: TestRepo
      end

      # Restore the original config
      :persistent_term.put({:drops_config, :registered_extensions}, original_config)

      # Module should be defined successfully
      assert Code.ensure_loaded?(TestOperationWithoutApp)
    end

    test "built-in extensions are available even when application not started" do
      # Temporarily clear the persistent term to simulate app not started
      original_config = :persistent_term.get({:drops_config, :registered_extensions}, [])
      :persistent_term.erase({:drops_config, :registered_extensions})

      # Built-in extensions should still be available from app env
      available = Extension.available_extensions()
      assert Drops.Operations.Extensions.Ecto in available

      # Restore the original config
      :persistent_term.put({:drops_config, :registered_extensions}, original_config)
    end

    test "Ecto extension functions are available when application not started" do
      # Temporarily clear the persistent term to simulate app not started
      original_config = :persistent_term.get({:drops_config, :registered_extensions}, [])
      :persistent_term.erase({:drops_config, :registered_extensions})

      # Use Code.eval_string to define modules dynamically
      test_id = System.unique_integer([:positive])

      base_module_code = """
      defmodule TestBaseOps#{test_id} do
        use Drops.Operations, repo: TestRepo
      end
      """

      operation_module_code = """
      defmodule TestEctoOp#{test_id} do
        use TestBaseOps#{test_id}, type: :command

        def execute(context), do: {:ok, context}
      end
      """

      # Evaluate the module definitions
      Code.eval_string(base_module_code)
      Code.eval_string(operation_module_code)

      operation_module = Module.concat([:"TestEctoOp#{test_id}"])

      # Should have Ecto extension functions
      assert function_exported?(operation_module, :changeset, 1)
      assert function_exported?(operation_module, :validate_changeset, 1)
      assert function_exported?(operation_module, :cast_changeset, 1)

      # Restore the original config
      :persistent_term.put({:drops_config, :registered_extensions}, original_config)
    end

    test "register_extension/1 adds extension to registry" do
      # Register our test extension
      assert :ok = Extension.register_extension(TestExtension)

      # Verify it's in the registry
      assert TestExtension in Extension.registered_extensions()
      assert Extension.extension?(TestExtension)
    end

    test "register_extension/1 prevents duplicates" do
      # Register the same extension twice
      Extension.register_extension(TestExtension)
      initial_count = length(Extension.registered_extensions())

      Extension.register_extension(TestExtension)
      final_count = length(Extension.registered_extensions())

      # Count should be the same
      assert initial_count == final_count
    end

    test "extension?/1 returns false for non-registered extensions" do
      refute Extension.extension?(NonExistentExtension)
    end

    test "available_extensions/0 returns registered extensions" do
      Extension.register_extension(TestExtension)
      Extension.register_extension(ManualExtension)

      available = Extension.available_extensions()
      assert TestExtension in available
      assert ManualExtension in available
    end
  end

  describe "extension auto-discovery" do
    setup do
      Drops.Test.Config.put_test_config(
        registered_extensions: [TestExtension, ManualExtension]
      )

      :ok
    end

    test "enabled_extensions/1 includes auto-discovered extensions" do
      opts = [test_logging: true]
      enabled = Extension.enabled_extensions(opts)

      # TestExtension should be auto-discovered because test_logging is present
      assert TestExtension in enabled

      # ManualExtension should NOT be auto-discovered (always returns false)
      refute ManualExtension in enabled
    end

    test "enabled_extensions/1 excludes extensions that don't match criteria" do
      opts = [some_other_option: true]
      enabled = Extension.enabled_extensions(opts)

      # Neither extension should be enabled
      refute TestExtension in enabled
      refute ManualExtension in enabled
    end
  end

  describe "explicit extension configuration" do
    setup do
      Drops.Test.Config.put_test_config(
        registered_extensions: [TestExtension, ManualExtension]
      )

      :ok
    end

    test "enabled_extensions/1 includes explicitly configured extensions" do
      opts = [extensions: [ManualExtension]]
      enabled = Extension.enabled_extensions(opts)

      # ManualExtension should be enabled even though it doesn't auto-discover
      assert ManualExtension in enabled

      # TestExtension should NOT be enabled (not in explicit list and no test_logging)
      refute TestExtension in enabled
    end

    test "enabled_extensions/1 combines explicit and auto-discovered extensions" do
      opts = [test_logging: true, extensions: [ManualExtension]]
      enabled = Extension.enabled_extensions(opts)

      # Both extensions should be enabled
      # auto-discovered
      assert TestExtension in enabled
      # explicitly configured
      assert ManualExtension in enabled
    end

    test "enabled_extensions/1 deduplicates extensions" do
      opts = [test_logging: true, extensions: [TestExtension]]
      enabled = Extension.enabled_extensions(opts)

      # TestExtension should appear only once even though it's both auto-discovered and explicit
      assert TestExtension in enabled
      assert length(Enum.filter(enabled, &(&1 == TestExtension))) == 1
    end
  end

  describe "extension integration with operations" do
    setup do
      Drops.Test.Config.put_test_config(
        registered_extensions: [TestExtension, ManualExtension]
      )

      :ok
    end

    test "auto-discovered extension is applied to operation module" do
      defmodule TestOperationWithAutoExtension do
        use Drops.Operations, type: :command, test_logging: true

        def execute(context) do
          {:ok, context.params}
        end
      end

      # Verify the extension was loaded
      assert TestOperationWithAutoExtension.__test_extension_loaded?()
      assert function_exported?(TestOperationWithAutoExtension, :log_operation, 1)
    end

    test "explicitly configured extension is applied to operation module" do
      defmodule TestOperationWithManualExtension do
        use Drops.Operations, type: :command, extensions: [Test.Support.ManualExtension]

        def execute(context) do
          {:ok, context.params}
        end
      end

      # Verify the extension was loaded
      assert TestOperationWithManualExtension.__manual_extension_loaded?()

      assert function_exported?(
               TestOperationWithManualExtension,
               :manual_extension_active?,
               0
             )

      assert TestOperationWithManualExtension.manual_extension_active?()
    end

    test "multiple extensions can be applied together" do
      defmodule TestOperationWithBothExtensions do
        use Drops.Operations,
          type: :command,
          test_logging: true,
          extensions: [Test.Support.ManualExtension]

        def execute(context) do
          {:ok, context.params}
        end
      end

      # Verify both extensions were loaded
      assert TestOperationWithBothExtensions.__test_extension_loaded?()
      assert TestOperationWithBothExtensions.__manual_extension_loaded?()
      assert function_exported?(TestOperationWithBothExtensions, :log_operation, 1)

      assert function_exported?(
               TestOperationWithBothExtensions,
               :manual_extension_active?,
               0
             )
    end
  end
end
