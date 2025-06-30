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
      end

  ## Parameters

  - `opts` - The options passed to the Operations module

  ## Returns

  Returns `true` if the extension should be loaded, `false` otherwise.
  """
  @callback enabled?(opts :: keyword()) :: boolean()

  @doc """
  Returns quoted code to inject into runtime operation modules.

  This is called when creating operation modules that use a base operations
  module (runtime pattern).

  ## Parameters

  - `opts` - The merged options for the operation

  ## Returns

  Returns quoted Elixir code to be injected.
  """
  @callback extend_operation(opts :: keyword()) :: Macro.t()

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
  Get enabled extensions based on the provided options and registered extensions.

  Extensions are enabled if they are registered and their enabled?(opts) callback returns true.

  ## Parameters

  - `registered_extensions` - List of registered extension modules
  - `opts` - The options to check against

  ## Returns

  Returns a list of extension modules that should be enabled.
  """
  def enabled_extensions(registered_extensions, opts) do
    registered_extensions
    |> Enum.filter(fn extension -> extension.enabled?(opts) end)
    |> Enum.uniq()
  end

  @doc """
  Generate extension code for runtime operation modules.

  ## Parameters

  - `registered_extensions` - List of registered extension modules
  - `opts` - The merged options for the operation

  ## Returns

  Returns quoted code from all enabled extensions.
  """
  def extend_operation(registered_extensions, opts) do
    enabled_extensions(registered_extensions, opts)
    |> Enum.map(& &1.extend_operation(opts))
  end

  @doc """
  Apply UnitOfWork extensions to modify the processing pipeline.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `registered_extensions` - List of registered extension modules
  - `opts` - The options for the operation

  ## Returns

  Returns the modified UnitOfWork with extension overrides applied.
  """
  def extend_unit_of_work(uow, registered_extensions, opts) do
    enabled_extensions(registered_extensions, opts)
    |> Enum.reduce(uow, fn extension, acc_uow ->
      if function_exported?(extension, :extend_unit_of_work, 2) do
        extension.extend_unit_of_work(acc_uow, opts)
      else
        acc_uow
      end
    end)
  end
end
