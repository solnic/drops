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

  Extensions must be registered before they can be used:

      # Register an extension
      Drops.Operations.Extension.register_extension(MyExtension)

      # Check if an extension is registered
      Drops.Operations.Extension.extension?(MyExtension)
      # => true

      # Get all registered extensions
      Drops.Operations.Extension.registered_extensions()
      # => [MyExtension, ...]

  ## Extension Discovery and Configuration

  Extensions can be enabled in two ways:

  ### 1. Auto-discovery

  Extensions are automatically discovered if they return `true` from `enabled?/1`
  when passed the operation options:

      defmodule MyOperation do
        use Drops.Operations, type: :command, my_option: true
        # MyExtension will be auto-discovered and applied
      end

  ### 2. Explicit configuration

  Extensions can be explicitly configured using the `:extensions` option:

      defmodule MyOperation do
        use Drops.Operations, type: :command, extensions: [MyExtension]
        # MyExtension will be applied regardless of enabled?/1 result
      end

  Both auto-discovered and explicitly configured extensions will be applied,
  with duplicates automatically removed.
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
  Register an extension to make it available for use.

  Extensions must be registered before they can be discovered or explicitly configured.
  This function stores the extension in a persistent term for efficient lookup.

  ## Parameters

  - `module` - The extension module to register

  ## Returns

  Returns `:ok` on success. Duplicate registrations are ignored.

  ## Examples

      Drops.Operations.Extension.register_extension(MyExtension)
      # => :ok

  """
  @spec register_extension(module()) :: :ok
  def register_extension(module) when is_atom(module) do
    current_extensions = registered_extensions()

    unless module in current_extensions do
      Drops.Config.put_config(:registered_extensions, [module | current_extensions])
    end

    :ok
  end

  @doc """
  Check if an extension is registered.

  ## Parameters

  - `module` - The extension module to check

  ## Returns

  Returns `true` if the extension is registered, `false` otherwise.

  """
  @spec extension?(module()) :: boolean()
  def extension?(module) when is_atom(module) do
    module in registered_extensions()
  end

  @doc """
  Get all registered extensions.

  Returns a list of all extension modules that have been registered.

  ## Returns

  Returns a list of extension modules.

  ## Examples

      Drops.Operations.Extension.registered_extensions()
      # => [MyExtension, AnotherExtension]

  """
  @spec registered_extensions() :: [module()]
  def registered_extensions do
    Drops.Config.registered_extensions()
  end

  @doc """
  Get all available extensions.

  This function returns all registered extensions that implement the Extension behaviour.
  """
  def available_extensions do
    registered_extensions()
  end

  @doc """
  Get enabled extensions based on the provided options.

  Extensions can be enabled in two ways:
  1. Auto-discovery: Extensions that return `true` from their `enabled?/1` callback
  2. Explicit configuration: Extensions specified in the `:extensions` option

  ## Parameters

  - `opts` - The options to check against

  ## Returns

  Returns a list of extension modules that should be enabled.
  """
  def enabled_extensions(opts) do
    # Get explicitly configured extensions and resolve any AST to actual modules
    explicit_extensions =
      opts
      |> Keyword.get(:extensions, [])
      |> Enum.map(&resolve_module/1)
      |> Enum.filter(&is_atom/1)

    # Get auto-discovered extensions
    auto_discovered =
      available_extensions()
      |> Enum.filter(& &1.enabled?(opts))

    # Combine and deduplicate
    (explicit_extensions ++ auto_discovered)
    |> Enum.uniq()
  end

  # Helper function to resolve module names from AST
  defp resolve_module({:__aliases__, _, module_parts}) do
    Module.concat(module_parts)
  end

  defp resolve_module(module) when is_atom(module) do
    module
  end

  defp resolve_module(_), do: nil

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
