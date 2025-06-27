defmodule Test.Support.TestExtension do
  @moduledoc """
  A test extension for verifying the Operations.Extension API.

  This extension adds logging functionality and custom validation
  to operations when the :test_logging option is present.
  """

  @behaviour Drops.Operations.Extension

  @impl true
  def enabled?(opts) do
    Keyword.has_key?(opts, :test_logging)
  end

  @impl true
  def extend_using_macro(opts) do
    if Keyword.get(opts, :test_logging) do
      quote do
        # Add a module attribute to track that this extension was loaded
        @test_extension_loaded true

        # Define a function to check if the extension is loaded
        def __test_extension_loaded?, do: @test_extension_loaded

        # Add logging function
        def log_operation(message) do
          IO.puts("[TestExtension] #{__MODULE__}: #{message}")
        end
      end
    else
      quote do
      end
    end
  end

  @impl true
  def extend_operation_runtime(opts) do
    if Keyword.get(opts, :test_logging) do
      quote do
        # Add logging to runtime operations
        def log_operation(message) do
          IO.puts("[TestExtension] #{__MODULE__}: #{message}")
        end

        # Override prepare to add logging
        def prepare(context) do
          log_operation("Preparing operation with params: #{inspect(context.params)}")
          super(context)
        end
      end
    else
      quote do
      end
    end
  end

  @impl true
  def extend_operation_definition(opts) do
    if Keyword.get(opts, :test_logging) do
      quote do
        # Add logging to compile-time operations
        def log_operation(message) do
          IO.puts("[TestExtension] #{__MODULE__}: #{message}")
        end
      end
    else
      quote do
      end
    end
  end

  @impl true
  def extend_unit_of_work(uow, opts) do
    if Keyword.get(opts, :test_logging) do
      # Add a custom step to the UnitOfWork for logging
      %{
        uow
        | prepare: fn context ->
            IO.puts("[TestExtension UoW] Preparing: #{inspect(context.params)}")
            uow.prepare.(context)
          end
      }
    else
      uow
    end
  end
end
