defmodule Drops.Test.Config do
  @moduledoc """
  Test helpers for Drops tests.

  This module provides utilities for managing configuration during tests,
  ensuring proper isolation between test runs.
  """

  @doc """
  Sets test configuration for Drops and ensures it's restored after the test.

  This function temporarily overrides Drops configuration for the duration of a test,
  automatically restoring the original configuration when the test completes.

  ## Examples

      test "with custom types" do
        put_test_config(registered_types: [MyApp.CustomType])
        # Test code here
      end

      test "with custom extensions" do
        put_test_config(registered_extensions: [MyApp.CustomExtension])
        # Test code here
      end
  """
  @spec put_test_config(keyword()) :: :ok
  def put_test_config(config) when is_list(config) do
    original_config =
      for {key, val} <- config do
        current_val = get_current_config_value(key)
        Drops.Config.put_config(key, val)
        {key, current_val}
      end

    ExUnit.Callbacks.on_exit(fn ->
      Enum.each(original_config, fn
        {key, :__not_set__} ->
          # Erase the key if it wasn't set before
          :persistent_term.erase({:drops_config, key})

        {key, original_val} ->
          # Restore the original value
          :persistent_term.put({:drops_config, key}, original_val)
      end)
    end)

    :ok
  end

  @spec get_current_config_value(atom()) :: term() | :__not_set__
  defp get_current_config_value(key) do
    :persistent_term.get({:drops_config, key}, :__not_set__)
  end
end
