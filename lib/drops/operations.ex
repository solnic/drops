defmodule Drops.Operations do
  @moduledoc """
  Operations module for defining command and query operations.

  This module provides a framework for defining operations that can be used
  to encapsulate business logic with input validation and execution.
  """

  defmodule Success do
    @type t :: %__MODULE__{}

    defstruct [:type, :operation, :result, :params]
  end

  defmodule Failure do
    @type t :: %__MODULE__{}

    defstruct [:type, :operation, :result, :params]
  end

  @doc """
  Callback for executing an operation with given parameters.
  """
  @callback execute(params :: any()) :: {:ok, any()} | {:error, any()}

  @doc """
  Callback for executing an operation with a previous result and new parameters.
  Used for composing operations with the pipeline operator.
  """
  @callback execute(previous_result :: any(), params :: any()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Callback for preparing parameters before execution.
  """
  @callback prepare(params :: any()) :: any()

  @callback validate(params :: any()) :: {:ok, any()} | {:error, any()}

  @doc """
  Before compile callback to extend UoW after all schema macros have been processed.
  """
  defmacro __before_compile__(env) do
    # Get the module being compiled
    module = env.module

    # Check if we need to extend the UoW based on schema metadata
    final_schema_meta = Module.get_attribute(module, :schema_meta, %{})

    if map_size(final_schema_meta) > 0 do
      # We have schema metadata, so extend the UoW
      operation_opts = Module.get_attribute(module, :operation_opts, [])
      unit_of_work = Module.get_attribute(module, :unit_of_work)
      final_opts = Keyword.put(operation_opts, :schema_meta, final_schema_meta)

      final_extended_uow =
        Drops.Operations.Extension.extend_unit_of_work(unit_of_work, final_opts)

      quote do
        # Define the function to return the extended UoW
        def __unit_of_work__, do: unquote(Macro.escape(final_extended_uow))
      end
    else
      quote do
        # No schema metadata, use the base UoW
        def __unit_of_work__, do: @unit_of_work
      end
    end
  end

  # Public API functions that operations delegate to
  def call(operation_module, params) do
    operation_type = operation_module.__operation_type__()
    uow = operation_module.__unit_of_work__()

    case process(uow, params, operation_type) do
      {:ok, pipeline_result} ->
        case operation_module.execute(pipeline_result.validated) do
          {:ok, result} ->
            {:ok,
             %__MODULE__.Success{
               operation: operation_module,
               result: result,
               params: pipeline_result.prepared,
               type: operation_type
             }}

          {:error, error} ->
            {:error,
             %__MODULE__.Failure{
               operation: operation_module,
               result: error,
               params: pipeline_result.prepared,
               type: operation_type
             }}
        end

      {:error, errors} ->
        {:error,
         %__MODULE__.Failure{
           operation: operation_module,
           result: errors,
           params: params,
           type: operation_type
         }}
    end
  end

  # Pattern match on Success struct - extract result and continue with pipeline
  def call(operation_module, {:ok, %__MODULE__.Success{result: previous_result}}, params) do
    operation_type = operation_module.__operation_type__()
    uow = operation_module.__unit_of_work__()

    case process(uow, params, operation_type) do
      {:ok, pipeline_result} ->
        case operation_module.execute(previous_result, pipeline_result.validated) do
          {:ok, result} ->
            {:ok,
             %__MODULE__.Success{
               operation: operation_module,
               result: result,
               params: pipeline_result.prepared,
               type: operation_type
             }}

          {:error, error} ->
            {:error,
             %__MODULE__.Failure{
               operation: operation_module,
               result: error,
               params: pipeline_result.prepared,
               type: operation_type
             }}
        end

      {:error, errors} ->
        {:error,
         %__MODULE__.Failure{
           operation: operation_module,
           result: errors,
           params: params,
           type: operation_type
         }}
    end
  end

  # Pattern match on Failure struct - return as-is to short-circuit pipeline
  def call(_operation_module, {:error, %__MODULE__.Failure{} = failure}, _params) do
    {:error, failure}
  end

  def process(uow, params, _operation_type) do
    Drops.Operations.UnitOfWork.process(uow, params)
  end

  def execute(_operation_module, _params) do
    raise "execute/1 must be implemented"
  end

  def execute(_operation_module, _previous_result, _params) do
    raise "execute/2 must be implemented for operations that support composition"
  end

  def prepare(_operation_module, params) do
    params
  end

  def validate(_operation_module, params) do
    params
  end

  defmacro __using__(opts) do
    quote do
      import Drops.Operations

      # Store the app-level options (like repo) to pass to operations
      @app_opts unquote(opts)

      # Define a function to return the app options
      def __app_opts__, do: @app_opts

      # Apply extensions to the main using macro
      unquote_splicing(Drops.Operations.Extension.extend_using_macro(opts))

      defmacro __using__(opts) when opts == [] do
        # When used without arguments, use this module as a base operations module
        Drops.Operations.__define_operation__(@app_opts, __MODULE__)
      end

      defmacro __using__(type) when is_atom(type) do
        # Merge app-level options with operation-specific options
        merged_opts = Keyword.merge(@app_opts, type: type)
        Drops.Operations.__define_operation__(merged_opts, nil)
      end

      defmacro __using__(opts) when is_list(opts) do
        unless Keyword.has_key?(opts, :type) do
          raise ArgumentError, "type option is required when using Drops.Operations"
        end

        # Merge app-level options with operation-specific options
        merged_opts = Keyword.merge(@app_opts, opts)
        Drops.Operations.__define_operation__(merged_opts, nil)
      end
    end
  end

  @doc false
  def __define_operation__(opts, base_module \\ nil) do
    # Determine which extension code to use based on whether we have a base module
    extension_code =
      if base_module do
        # Get the app options at compile time for runtime operations
        app_opts = base_module.__app_opts__()
        Drops.Operations.Extension.extend_operation_runtime(app_opts)
      else
        Drops.Operations.Extension.extend_operation_definition(opts)
      end

    quote location: :keep do
      @behaviour Drops.Operations

      use Drops.Contract

      # Conditional import for base module pattern
      unquote(
        if base_module do
          quote do: import(unquote(base_module))
        end
      )

      # Store the repo configuration if provided
      @repo unquote(opts[:repo])

      # Store the operation type
      @operation_type unquote(opts[:type])

      # Store the operation options for extension access
      @app_opts unquote(opts)

      # Set default schema options based on operation type
      @schema_opts (case unquote(opts[:type]) do
                      :form -> [atomize: true]
                      _ -> []
                    end)

      # Define a function to return the app options
      def __app_opts__, do: @app_opts

      schema do
        %{}
      end

      # Create and store the UnitOfWork
      @unit_of_work Drops.Operations.UnitOfWork.new(__MODULE__)

      # Store options for UoW extension
      @operation_opts unquote(opts)

      # Initialize extended UoW to base UoW (not used anymore, kept for compatibility)
      @extended_unit_of_work @unit_of_work

      # Use @before_compile to process schema callbacks after all schemas are set
      @before_compile Drops.Operations

      # Accessor functions for module attributes
      def __repo__, do: @repo
      def __operation_type__, do: @operation_type

      # Always delegate to the main module to eliminate duplication
      def call(params) do
        Drops.Operations.call(__MODULE__, params)
      end

      def call(previous_result, params) do
        Drops.Operations.call(__MODULE__, previous_result, params)
      end

      def execute(params) do
        Drops.Operations.execute(__MODULE__, params)
      end

      def execute(previous_result, params) do
        Drops.Operations.execute(__MODULE__, previous_result, params)
      end

      def prepare(params) do
        Drops.Operations.prepare(__MODULE__, params)
      end

      def validate(params) when is_map(params) do
        Drops.Operations.validate(__MODULE__, params)
      end

      # Apply extensions
      unquote_splicing(extension_code)

      defoverridable execute: 1
      defoverridable execute: 2
      defoverridable prepare: 1
      defoverridable validate: 1
    end
  end
end
