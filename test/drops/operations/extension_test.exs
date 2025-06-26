defmodule Drops.Operations.ExtensionTest do
  use ExUnit.Case, async: true

  alias Drops.Operations.Extension
  alias Drops.Operations.Extensions.Ecto

  describe "available_extensions/0" do
    test "returns list of available extensions" do
      extensions = Extension.available_extensions()
      assert Ecto in extensions
    end
  end

  describe "enabled_extensions/1" do
    test "returns empty list when no extensions are enabled" do
      opts = []
      assert Extension.enabled_extensions(opts) == []
    end

    test "returns Ecto extension when repo is configured" do
      opts = [repo: Test.Repo]
      enabled = Extension.enabled_extensions(opts)
      assert Ecto in enabled
    end

    test "does not return Ecto extension when repo is nil" do
      opts = [repo: nil]
      enabled = Extension.enabled_extensions(opts)
      assert Ecto not in enabled
    end

    test "does not return Ecto extension when repo is not configured" do
      opts = [type: :command]
      enabled = Extension.enabled_extensions(opts)
      assert Ecto not in enabled
    end
  end

  describe "extend_using_macro/1" do
    test "returns empty list when no extensions are enabled" do
      opts = []
      result = Extension.extend_using_macro(opts)
      assert result == []
    end

    test "returns extension code when Ecto extension is enabled" do
      opts = [repo: Test.Repo]
      result = Extension.extend_using_macro(opts)
      assert is_list(result)
    end
  end

  describe "extend_operation_runtime/1" do
    test "returns empty list when no extensions are enabled" do
      opts = []
      result = Extension.extend_operation_runtime(opts)
      assert result == []
    end

    test "returns extension code when Ecto extension is enabled" do
      opts = [repo: Test.Repo]
      result = Extension.extend_operation_runtime(opts)
      assert is_list(result)
      # Should contain quoted code
      assert length(result) > 0
    end
  end

  describe "extend_operation_definition/1" do
    test "returns empty list when no extensions are enabled" do
      opts = []
      result = Extension.extend_operation_definition(opts)
      assert result == []
    end

    test "returns extension code when Ecto extension is enabled" do
      opts = [repo: Test.Repo]
      result = Extension.extend_operation_definition(opts)
      assert is_list(result)
      # Should contain quoted code
      assert length(result) > 0
    end
  end
end
