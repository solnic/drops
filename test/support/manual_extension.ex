defmodule Test.Support.ManualExtension do
  @moduledoc """
  A test extension that must be explicitly configured.

  This extension never auto-enables (always returns false from enabled?/1)
  and must be explicitly included in the :extensions option.
  """

  @behaviour Drops.Operations.Extension

  @impl true
  def enabled?(_opts) do
    # This extension never auto-enables
    false
  end

  @impl true
  def extend_using_macro(_opts) do
    quote do
      # Add a module attribute to track that this extension was loaded
      @manual_extension_loaded true

      # Define a function to check if the extension is loaded
      def __manual_extension_loaded?, do: @manual_extension_loaded

      # Add a function to indicate this extension is active
      def manual_extension_active?, do: true
    end
  end

  @impl true
  def extend_operation_runtime(_opts) do
    quote do
      # Add a function to indicate this extension is active
      def manual_extension_active?, do: true
    end
  end

  @impl true
  def extend_operation_definition(_opts) do
    quote do
      # Add a function to indicate this extension is active
      def manual_extension_active?, do: true
    end
  end
end
