defmodule Drops.Operations.ExtensionTest do
  use Drops.OperationCase, async: false

  Code.require_file("test/support/test_extension.ex")
  Code.require_file("test/support/manual_extension.ex")

  alias Test.Extensions, as: Exts

  describe "extension registration" do
    test "register_extension/1 adds new extensions to registry" do
      defmodule Test.MyOperations do
        use Drops.Operations

        register_extension(Exts.PrepareExtension)
        register_extension(Exts.ManualExtension)
      end

      assert Test.MyOperations.registered_extensions() == [
               Exts.PrepareExtension,
               Exts.ManualExtension
             ]
    end

    test "operations inherit extensions from base module" do
      defmodule Test.MyOperationsWithExtensions do
        use Drops.Operations

        register_extension(Exts.PrepareExtension)
      end

      defmodule Test.MyOperation do
        use Test.MyOperationsWithExtensions

        def execute(context) do
          {:ok, context}
        end
      end

      assert Test.MyOperationsWithExtensions.registered_extensions() == [
               Exts.PrepareExtension
             ]
    end
  end

  describe "extension behavior verification" do
    test "PrepareExtension modifies params in prepare step" do
      defmodule Test.PrepareOperations do
        use Drops.Operations

        register_extension(Exts.PrepareExtension)
      end

      defmodule Test.PrepareOperation do
        use Test.PrepareOperations

        schema do
          %{
            required(:name) => string()
          }
        end

        @impl true
        def execute(%{params: params}) do
          {:ok, params}
        end
      end

      {:ok, result} = Test.PrepareOperation.call(%{params: %{name: "test"}})
      assert result == %{name: "prepared_test"}
    end

    test "ValidateExtension adds custom validation" do
      defmodule Test.ValidateOperations do
        use Drops.Operations

        register_extension(Exts.ValidateExtension)
      end

      defmodule Test.ValidateOperation do
        use Test.ValidateOperations

        schema do
          %{
            required(:name) => string()
          }
        end

        @impl true
        def execute(%{params: params}) do
          {:ok, params}
        end
      end

      {:ok, result} = Test.ValidateOperation.call(%{params: %{name: "valid_name"}})
      assert result == %{name: "valid_name"}

      {:error, error} = Test.ValidateOperation.call(%{params: %{name: "invalid_name"}})
      assert error == "name cannot contain 'invalid'"
    end

    test "multiple extensions work together" do
      defmodule Test.MultiExtensionOperations do
        use Drops.Operations

        register_extension(Exts.PrepareExtension)
        register_extension(Exts.ValidateExtension)
      end

      defmodule Test.MultiExtensionOperation do
        use Test.MultiExtensionOperations

        schema do
          %{
            required(:name) => string()
          }
        end

        @impl true
        def execute(%{params: params}) do
          {:ok, params}
        end
      end

      {:ok, result} = Test.MultiExtensionOperation.call(%{params: %{name: "test"}})
      assert result == %{name: "prepared_test"}

      {:error, error} = Test.MultiExtensionOperation.call(%{params: %{name: "invalid"}})
      assert error == "name cannot contain 'invalid'"
    end
  end
end
