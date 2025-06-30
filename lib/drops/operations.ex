defmodule Drops.Operations do
  @moduledoc """
  Operations module for defining command and query operations.

  This module provides a framework for defining operations that can be used
  to encapsulate business logic with input validation and execution.

  ## Extension Registration

  Extensions can be registered using the `register_extension` macro:

      defmodule MyApp.Operations do
        use Drops.Operations

        register_extension(MyApp.Extensions.Audit)
      end

  """

  require Drops.Operations.Extension

  alias Drops.Operations.{Extension, UnitOfWork}

  defmodule Success do
    @type t :: %__MODULE__{}

    defstruct [:type, :operation, :result, :params]
  end

  defmodule Failure do
    @type t :: %__MODULE__{}

    defstruct [:type, :operation, :result, :params]
  end

  @doc """
  Callback for executing an operation with given context.
  The context is a map that contains at least a :params key.
  """
  @callback execute(context :: map()) :: {:ok, any()} | {:error, any()}

  @doc """
  Callback for executing an operation with a previous result and new context.
  Used for composing operations with the pipeline operator.
  """
  @callback execute(previous_result :: any(), context :: map()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Callback for finalizing the operation result.
  This extracts the actual result from the Operation result struct for the public API.
  """
  @callback finalize(result_struct :: Success.t() | Failure.t()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Callback for preparing parameters before execution.
  Receives context map and should return updated params.
  """
  @callback prepare(context :: map()) :: any()

  @doc """
  Callback for validating parameters.
  Receives context map and should return validated params or error.
  """
  @callback validate(context :: map()) :: {:ok, any()} | {:error, any()}

  @doc """
  Before compile callback to extend UoW after all schema macros have been processed.
  """
  defmacro __before_compile__(env) do
    module = env.module
    opts = Module.get_attribute(module, :opts)
    registered_extensions = Module.get_attribute(module, :registered_extensions, [])
    enabled_extensions = Module.get_attribute(module, :enabled_extensions, [])

    schema_meta = Module.get_attribute(module, :schema_meta, %{})

    uow_code =
      if map_size(schema_meta) > 0 do
        unit_of_work = Module.get_attribute(module, :unit_of_work)
        final_opts = Keyword.put(opts, :schema_meta, schema_meta)

        final_extended_uow =
          Drops.Operations.Extension.extend_unit_of_work(
            unit_of_work,
            enabled_extensions,
            final_opts
          )

        quote do
          def __unit_of_work__, do: unquote(Macro.escape(final_extended_uow))
        end
      else
        unit_of_work = Module.get_attribute(module, :unit_of_work)

        quote do
          def __unit_of_work__, do: unquote(Macro.escape(unit_of_work))
        end
      end

    quote do
      def registered_extensions, do: unquote(Enum.reverse(registered_extensions))

      def enabled_extensions, do: unquote(Enum.reverse(enabled_extensions))

      unquote(uow_code)
    end
  end

  @doc """
  Register an extension module for this operations module.

  This macro accumulates extension modules in the `:registered_extensions` module attribute.
  When operations are defined using this module as a base, they will automatically
  be extended with the registered extensions.

  ## Parameters

  - `extension` - The extension module to register

  ## Example

      defmodule MyApp.Operations do
        use Drops.Operations

        register_extension(MyApp.Extensions.Audit)
        register_extension(MyApp.Extensions.Cache)
      end
  """
  defmacro register_extension(extension) do
    quote do
      @registered_extensions unquote(extension)
    end
  end

  # Public API functions that operations delegate to
  def call(operation_module, input) do
    uow = operation_module.__unit_of_work__()

    # Extract context and params from input
    context = normalize_input(input)

    # Use the full UoW pipeline which includes execute and finalize
    Drops.Operations.UnitOfWork.process(uow, context)
  end

  # Pattern match on finalized success result - extract result and continue with pipeline
  def call(operation_module, {:ok, previous_result}, input) do
    uow = operation_module.__unit_of_work__()

    # Extract context and params from input
    context = normalize_input(input)
    # Add the previous result to the context for composition
    context_with_previous = Map.put(context, :execute_result, previous_result)

    # Use the full UoW pipeline which includes execute and finalize
    Drops.Operations.UnitOfWork.process(uow, context_with_previous)
  end

  # Pattern match on finalized error result - return as-is to short-circuit pipeline
  def call(_operation_module, {:error, _error} = error_result, _input) do
    error_result
  end

  # Normalize input to ensure we have a context map with at least params
  defp normalize_input(%{params: _params} = context) when is_map(context) do
    context
  end

  defp normalize_input(params) do
    %{params: params}
  end

  def execute(_operation_module, _context) do
    raise "execute/1 must be implemented"
  end

  def execute(_operation_module, _previous_result, _context) do
    raise "execute/2 must be implemented for operations that support composition"
  end

  def prepare(_operation_module, context) do
    context
  end

  def validate(_operation_module, context) do
    context
  end

  def finalize(_operation_module, %__MODULE__.Success{result: result}) do
    {:ok, result}
  end

  def finalize(_operation_module, %__MODULE__.Failure{result: result}) do
    {:error, result}
  end

  defmacro __using__(opts) do
    quote do
      import Drops.Operations

      @opts unquote(opts)
      def __opts__, do: @opts

      Module.register_attribute(__MODULE__, :registered_extensions, accumulate: true)

      @before_compile Drops.Operations

      import Drops.Operations, only: [register_extension: 1]

      defmacro __using__(opts) when opts == [] do
        Drops.Operations.__define_operation__(@opts, __MODULE__)
      end

      defmacro __using__(type) when is_atom(type) do
        merged_opts = Keyword.merge(@opts, type: type)
        Drops.Operations.__define_operation__(merged_opts, __MODULE__)
      end

      defmacro __using__(opts) when is_list(opts) do
        unless Keyword.has_key?(opts, :type) do
          raise ArgumentError, "type option is required when using Drops.Operations"
        end

        merged_opts = Keyword.merge(@opts, opts)
        Drops.Operations.__define_operation__(merged_opts, __MODULE__)
      end
    end
  end

  @doc false
  def __define_operation__(opts, base_module) do
    final_opts = Keyword.merge(base_module.__opts__(), opts)

    enabled_extensions =
      Extension.enabled_extensions(base_module.registered_extensions(), final_opts)

    extension_code = Extension.extend_operation(enabled_extensions, final_opts)

    quote location: :keep do
      @behaviour Drops.Operations

      use Drops.Contract

      # Conditional import for base module pattern
      unquote(
        if base_module do
          quote do: import(unquote(base_module))
        end
      )

      @enabled_extensions unquote(enabled_extensions)
      @operation_type unquote(opts[:type])
      @opts unquote(final_opts)
      @schema_opts if unquote(opts[:type]) == :form, do: [atomize: true], else: []
      @unit_of_work UnitOfWork.new(__MODULE__)

      @before_compile Drops.Operations

      schema do
        %{}
      end

      def __opts__, do: @opts
      def __operation_type__, do: @operation_type

      # Always delegate to the main module to eliminate duplication
      def call(input) do
        Drops.Operations.call(__MODULE__, input)
      end

      def call(previous_result, input) do
        Drops.Operations.call(__MODULE__, previous_result, input)
      end

      def execute(context) do
        Drops.Operations.execute(__MODULE__, context)
      end

      def execute(previous_result, context) do
        Drops.Operations.execute(__MODULE__, previous_result, context)
      end

      def prepare(context) do
        Drops.Operations.prepare(__MODULE__, context)
      end

      def validate(context) when is_map(context) do
        Drops.Operations.validate(__MODULE__, context)
      end

      def finalize(result_struct) do
        Drops.Operations.finalize(__MODULE__, result_struct)
      end

      defoverridable execute: 1
      defoverridable execute: 2
      defoverridable prepare: 1
      defoverridable validate: 1
      defoverridable finalize: 1

      # Apply extensions after defoverridable declarations
      unquote_splicing(extension_code)
    end
  end
end
