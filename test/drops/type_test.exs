defmodule Drops.TypeTest do
  use Drops.ContractCase, async: false
  use Drops.DoctestCase

  import Drops.Test.Config

  defmodule Email do
    use Drops.Type, string()
  end

  defmodule FilledEmail do
    use Drops.Type, string(:filled?)
  end

  defmodule User do
    use Drops.Type, %{
      required(:name) => string(),
      required(:email) => string()
    }
  end

  defmodule Price do
    use Drops.Type, union([:integer, :float], gt?: 0)
  end

  doctest Drops.Type

  describe "type registry" do
    setup do
      # Register the test types for these tests
      put_test_config(registered_types: [Email, FilledEmail, User, Price])
      :ok
    end

    test "registered_types/0 returns list of all registered types" do
      types = Drops.Type.registered_types()

      assert Email in types
      assert FilledEmail in types
      assert User in types
      assert Price in types
    end

    test "type?/1 returns true for registered Drops types" do
      assert Drops.Type.type?(Email)
      assert Drops.Type.type?(FilledEmail)
      assert Drops.Type.type?(User)
      assert Drops.Type.type?(Price)
    end

    test "type?/1 returns false for non-Drops types" do
      refute Drops.Type.type?(String)
    end

    test "register_type/1 adds new types to registry" do
      defmodule RuntimeType do
        use Drops.Type, string()
      end

      # Register the type explicitly
      Drops.Type.register_type(RuntimeType)

      assert Drops.Type.type?(RuntimeType)
      assert RuntimeType in Drops.Type.registered_types()
    end
  end
end
