defmodule Drops.Operations do
  @moduledoc """
  Operations module for defining command and query operations.

  This module provides a framework for defining operations that can be used
  to encapsulate business logic with input validation and execution.

  ## Extension Registration

  Extensions can be registered using the public API:

      defmodule MyApp.Operations do
        use Drops.Operations

        # Register built-in extensions
        Drops.Operations.Extension.register(Drops.Operations.Extensions.Ecto)

        # Register custom extensions
        Drops.Operations.Extension.register(MyApp.Extensions.Audit)
      end

  """

  require Drops.Operations.Extension
  require Drops.Operations.Extensions.Ecto

  # Register built-in extensions using the new public API
  Drops.Operations.Extension.register(Drops.Operations.Extensions.Ecto)

  alias Drops.Operations.UnitOfWork

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
  Callback for finalizing the operation result.
  This extracts the actual result from the Operation result struct for the public API.
  """
  @callback finalize(result_struct :: Success.t() | Failure.t()) ::
              {:ok, any()} | {:error, any()}

  @doc """
  Callback for preparing parameters before execution.
  Receives context map and should return updated context.
  """
  @callback prepare(context :: map()) :: {:ok, map()} | {:error, any()}

  @doc """
  Callback for validating parameters.
  Receives context map and should return validated context or error.
  """
  @callback validate(context :: map()) :: {:ok, map()} | {:error, any()}

  @optional_callbacks prepare: 1, validate: 1, finalize: 1

  @doc """
  Before compile callback to extend UoW after all schema macros have been processed.
  """
  defmacro __before_compile__(env) do
    module = env.module
    final_schema_meta = Module.get_attribute(module, :schema_meta, %{})

    if map_size(final_schema_meta) > 0 do
      operation_opts = Module.get_attribute(module, :operation_opts, [])
      unit_of_work = Module.get_attribute(module, :unit_of_work)
      final_opts = Keyword.put(operation_opts, :schema_meta, final_schema_meta)

      final_extended_uow =
        Drops.Operations.Extension.extend_unit_of_work(unit_of_work, final_opts)

      quote do
        def __unit_of_work__, do: unquote(Macro.escape(final_extended_uow))
      end
    else
      quote do
        def __unit_of_work__, do: @unit_of_work
      end
    end
  end

  defmacro __using__(opts) do
    quote do
      import Drops.Operations

      @app_opts unquote(opts)

      def __app_opts__, do: @app_opts

      unquote_splicing(Drops.Operations.Extension.extend_using_macro(opts))

      defmacro __using__(opts) when opts == [] do
        Drops.Operations.__define_operation__(@app_opts, __MODULE__)
      end

      defmacro __using__(type) when is_atom(type) do
        merged_opts = Keyword.merge(@app_opts, type: type)
        Drops.Operations.__define_operation__(merged_opts, __MODULE__)
      end

      defmacro __using__(opts) when is_list(opts) do
        unless Keyword.has_key?(opts, :type) do
          raise ArgumentError, "type option is required when using Drops.Operations"
        end

        merged_opts = Keyword.merge(@app_opts, opts)
        Drops.Operations.__define_operation__(merged_opts, __MODULE__)
      end
    end
  end

  @doc false
  def __define_operation__(opts, base_module) do
    extension_code =
      Drops.Operations.Extension.extend_operation_runtime(opts)

    quote location: :keep do
      @behaviour Drops.Operations

      use Drops.Contract

      import unquote(base_module)

      @repo unquote(opts[:repo])
      @operation_type unquote(opts[:type])
      @app_opts unquote(opts)
      @schema_opts (case unquote(opts[:type]) do
                      :form -> [atomize: true]
                      _ -> []
                    end)

      @unit_of_work UnitOfWork.new(__MODULE__)
      @operation_opts unquote(opts)
      @before_compile Drops.Operations

      schema do
        %{}
      end

      def __app_opts__, do: @app_opts
      def __repo__, do: @repo
      def __operation_type__, do: @operation_type

      def call(context) do
        UnitOfWork.process(__unit_of_work__(), context)
      end

      def call({:ok, previous_result}, context) do
        UnitOfWork.process(
          __unit_of_work__(),
          Map.put(context, :execute_result, previous_result)
        )
      end

      def call({:error, _error} = error_result, _input) do
        error_result
      end

      def conform(%{params: params} = context) when is_map(context) do
        case super(params) do
          {:ok, conformed_params} ->
            {:ok, Map.put(context, :params, conformed_params)}

          {:error, _} = error ->
            error
        end
      end

      def execute(_context) do
        raise "execute/1 must be implemented"
      end

      def prepare(context) do
        {:ok, context}
      end

      def validate(context) when is_map(context) do
        {:ok, context}
      end

      def finalize(%Drops.Operations.Success{result: result}) do
        {:ok, result}
      end

      def finalize(%Drops.Operations.Failure{result: result}) do
        {:error, result}
      end

      defoverridable conform: 1
      defoverridable execute: 1
      defoverridable prepare: 1
      defoverridable validate: 1
      defoverridable finalize: 1

      unquote_splicing(extension_code)
    end
  end
end
