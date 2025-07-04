defmodule Drops.Operations.Extension do
  @moduledoc """
  Behaviour for defining Operations extensions.

  Extensions provide a way to add functionality to Operations by injecting
  steps into the processing pipeline, providing helper functions, and
  modifying the unit of work configuration.

  ## Callbacks

  Extensions must implement the following callbacks:

  - `enable?/1` - Determines if the extension should be enabled based on options
  - `unit_of_work/2` - Modifies the unit of work to add/modify steps
  - `default_opts/1` - Provides default options for the extension
  - `using/0` - Returns quoted code to inject into the using module
  - `helpers/0` - Returns quoted code for helper functions
  - `steps/0` - Returns quoted code for step function definitions

  ## Example

      defmodule MyExtension do
        use Drops.Operations.Extension

        @impl true
        def enable?(opts) do
          Keyword.get(opts, :my_feature, false)
        end

        @impl true
        def unit_of_work(uow, _opts) do
          add_step(uow, :my_step)
        end

        @impl true
        def using do
          quote do
            def my_helper, do: :helper_result
          end
        end

        steps do
          def my_step(context) do
            {:ok, Map.put(context, :my_step_executed, true)}
          end
        end
      end
  """

  @doc """
  Determines whether this extension should be enabled for the given options.

  This callback allows extensions to conditionally enable themselves based
  on the options passed to the operation.

  ## Parameters

  - `opts` - The options keyword list passed to the operation

  ## Returns

  - `true` if the extension should be enabled
  - `false` if the extension should be disabled

  ## Example

      @impl true
      def enable?(opts) do
        Keyword.has_key?(opts, :repo) && !is_nil(opts[:repo])
      end
  """
  @callback enable?(opts :: keyword()) :: boolean()

  @doc """
  Modifies the unit of work to configure the processing pipeline.

  This callback allows extensions to add steps, modify step order,
  or register callbacks in the unit of work.

  ## Parameters

  - `uow` - The current unit of work struct
  - `opts` - The options keyword list passed to the operation

  ## Returns

  The modified unit of work struct.

  ## Example

      @impl true
      def unit_of_work(uow, _opts) do
        uow
        |> add_step(:prepare)
        |> after_step(:prepare, :validate)
      end
  """
  @callback unit_of_work(uow :: map(), opts :: keyword()) :: map()

  @doc """
  Provides default options for the extension.

  This callback allows extensions to specify default configuration
  that will be merged with user-provided options.

  ## Parameters

  - `opts` - The current options keyword list

  ## Returns

  A keyword list of default options to merge.

  ## Example

      @impl true
      def default_opts(_opts) do
        [timeout: 5000, retries: 3]
      end
  """
  @callback default_opts(opts :: keyword()) :: keyword()

  @doc """
  Returns quoted code to inject into the using module.

  This callback allows extensions to add functions, imports, or other
  code directly into modules that use the extension.

  ## Returns

  Quoted Elixir code to inject into the using module.

  ## Example

      @impl true
      def using do
        quote do
          import MyHelpers
          @behaviour MyBehaviour
        end
      end
  """
  @callback using() :: Macro.t()

  @doc """
  Returns quoted code for helper functions.

  This callback allows extensions to provide utility functions
  that can be used by operations.

  ## Returns

  Quoted Elixir code defining helper functions.

  ## Example

      @impl true
      def helpers do
        quote do
          def format_error(error), do: "Error: " <> inspect(error)
        end
      end
  """
  @callback helpers() :: Macro.t()

  @doc """
  Returns quoted code for step function definitions.

  This callback allows extensions to define step functions that
  will be available to operations using the extension.

  ## Returns

  Quoted Elixir code defining step functions.

  ## Example

      @impl true
      def steps do
        quote do
          def validate(context) do
            # validation logic
            {:ok, context}
          end
        end
      end
  """
  @callback steps() :: Macro.t()

  defmacro __using__(opts) do
    quote do
      @behaviour Drops.Operations.Extension

      import Drops.Operations, only: [steps: 1]

      import Drops.Operations.UnitOfWork,
        only: [
          before_step: 3,
          after_step: 3,
          add_step: 2,
          register_before_callback: 5,
          register_after_callback: 5
        ]

      @opts unquote(opts)
      def __opts__, do: @opts

      @default_opts []
      def default_opts(_opts), do: @default_opts
      defoverridable default_opts: 1

      def using, do: []
      defoverridable using: 0

      def enable?(_opts), do: true
      defoverridable enable?: 1

      def unit_of_work(uow, _opts), do: uow
      defoverridable unit_of_work: 2

      def helpers, do: []
      defoverridable helpers: 0

      def steps, do: []
      defoverridable steps: 0

      defmacro __using__(opts) do
        extension = __MODULE__

        if extension.enable?(opts) do
          quote location: :keep do
            @enabled_extensions unquote(extension)

            merged_opts =
              Keyword.merge(@opts, unquote(extension).default_opts(@opts))

            @opts merged_opts

            unquote(extension.using())
          end
        else
          []
        end
      end
    end
  end
end
