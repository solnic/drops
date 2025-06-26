defmodule Drops.Operations.Extension do
  @moduledoc """
  Behaviour for Operations extensions.

  Extensions allow adding functionality to Operations modules based on configuration.
  For example, the Ecto extension adds changeset validation, persistence, and
  Phoenix.HTML.FormData protocol support when a repo is configured.

  ## Extension Interface

  Extensions must implement the following callbacks:

  - `enabled?/1` - Determines if the extension should be loaded based on options
  - `extend_using_macro/1` - Returns quoted code to inject into the `__using__` macro
  - `extend_operation_runtime/1` - Returns quoted code for runtime operation modules
  - `extend_operation_definition/1` - Returns quoted code for compile-time operation modules

  ## Example Extension

      defmodule MyExtension do
        @behaviour Drops.Operations.Extension

        @impl true
        def enabled?(opts) do
          Keyword.has_key?(opts, :my_option)
        end

        @impl true
        def extend_using_macro(opts) do
          quote do
            # Code to inject into the main __using__ macro
          end
        end

        @impl true
        def extend_operation_runtime(opts) do
          quote do
            # Code to inject into runtime operation modules
          end
        end

        @impl true
        def extend_operation_definition(opts) do
          quote do
            # Code to inject into compile-time operation modules
          end
        end
      end

  ## Extension Registration

  Extensions are automatically discovered and loaded based on their `enabled?/1` callback.
  The system checks all available extensions and includes those that return `true`.
  """

  @doc """
  Determines if this extension should be enabled based on the provided options.

  ## Parameters

  - `opts` - The options passed to the Operations module

  ## Returns

  Returns `true` if the extension should be loaded, `false` otherwise.
  """
  @callback enabled?(opts :: keyword()) :: boolean()

  @doc """
  Returns quoted code to inject into the main Operations `__using__` macro.

  This is called when the Operations module is used and allows extensions
  to add module attributes, imports, or other setup code.

  ## Parameters

  - `opts` - The options passed to the Operations module

  ## Returns

  Returns quoted Elixir code to be injected.
  """
  @callback extend_using_macro(opts :: keyword()) :: Macro.t()

  @doc """
  Returns quoted code to inject into runtime operation modules.

  This is called when creating operation modules that use a base operations
  module (runtime pattern).

  ## Parameters

  - `opts` - The merged options for the operation

  ## Returns

  Returns quoted Elixir code to be injected.
  """
  @callback extend_operation_runtime(opts :: keyword()) :: Macro.t()

  @doc """
  Returns quoted code to inject into compile-time operation modules.

  This is called when creating operation modules directly with options
  (compile-time pattern).

  ## Parameters

  - `opts` - The options for the operation

  ## Returns

  Returns quoted Elixir code to be injected.
  """
  @callback extend_operation_definition(opts :: keyword()) :: Macro.t()

  @doc """
  Allows extensions to modify the UnitOfWork for an operation.

  This is called after the UnitOfWork is created to allow extensions
  to override specific steps in the processing pipeline.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `opts` - The options for the operation

  ## Returns

  Returns the modified UnitOfWork.
  """
  @callback extend_unit_of_work(uow :: Drops.Operations.UnitOfWork.t(), opts :: keyword()) ::
              Drops.Operations.UnitOfWork.t()

  @optional_callbacks extend_unit_of_work: 2

  @doc """
  Get all available extensions.

  This function discovers all modules that implement the Extension behaviour.
  """
  def available_extensions do
    [
      Drops.Operations.Extensions.Ecto,
      Drops.Operations.Extensions.Telemetry
    ]
  end

  @doc """
  Get enabled extensions based on the provided options.

  ## Parameters

  - `opts` - The options to check against

  ## Returns

  Returns a list of extension modules that should be enabled.
  """
  def enabled_extensions(opts) do
    available_extensions()
    |> Enum.filter(& &1.enabled?(opts))
  end

  @doc """
  Generate extension code for the main `__using__` macro.

  ## Parameters

  - `opts` - The options passed to the Operations module

  ## Returns

  Returns quoted code from all enabled extensions.
  """
  def extend_using_macro(opts) do
    enabled_extensions(opts)
    |> Enum.map(& &1.extend_using_macro(opts))
  end

  @doc """
  Generate extension code for runtime operation modules.

  ## Parameters

  - `opts` - The merged options for the operation

  ## Returns

  Returns quoted code from all enabled extensions.
  """
  def extend_operation_runtime(opts) do
    enabled_extensions(opts)
    |> Enum.map(& &1.extend_operation_runtime(opts))
  end

  @doc """
  Generate extension code for compile-time operation modules.

  ## Parameters

  - `opts` - The options for the operation

  ## Returns

  Returns quoted code from all enabled extensions.
  """
  def extend_operation_definition(opts) do
    enabled_extensions(opts)
    |> Enum.map(& &1.extend_operation_definition(opts))
  end

  @doc """
  Apply UnitOfWork extensions to modify the processing pipeline.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `opts` - The options for the operation

  ## Returns

  Returns the modified UnitOfWork with extension overrides applied.
  """
  def extend_unit_of_work(uow, opts) do
    enabled_extensions(opts)
    |> Enum.reduce(uow, fn extension, acc_uow ->
      if function_exported?(extension, :extend_unit_of_work, 2) do
        extension.extend_unit_of_work(acc_uow, opts)
      else
        acc_uow
      end
    end)
  end
end
