defmodule Drops.Operations do
  @opts [
    type: :abstract,
    extensions: [
      Drops.Operations.Extensions.Command,
      Drops.Operations.Extensions.Params
    ]
  ]
  def __opts__, do: @opts

  alias Drops.Operations.UnitOfWork

  defmacro __using__(opts) do
    source_module = __MODULE__
    merged_opts = merge_opts(source_module.__opts__(), opts)

    merged_opts =
      Keyword.put(
        merged_opts,
        :extensions,
        Enum.map(merged_opts[:extensions], &Macro.expand(&1, __CALLER__))
      )

    define(merged_opts)
  end

  def define(opts) do
    use_extensions =
      Enum.map(opts[:extensions], &quote(do: use(unquote(&1), unquote(opts))))
      |> Enum.reverse()

    quote location: :keep do
      import Drops.Operations

      @opts unquote(opts)

      @unit_of_work Drops.Operations.UnitOfWork.new(__MODULE__, [])

      @extensions @opts[:extensions]
      def __extensions__, do: @extensions

      Module.register_attribute(__MODULE__, :enabled_extensions, accumulate: true)
      unquote_splicing(use_extensions)

      def __enabled_extensions__, do: @enabled_extensions

      def __opts__, do: @opts

      @before_compile Drops.Operations

      defmacro __using__(opts) do
        source_module = __MODULE__
        merged_opts = merge_opts(source_module.__opts__(), opts)

        merged_opts =
          Keyword.put(
            merged_opts,
            :extensions,
            Enum.map(merged_opts[:extensions], &Macro.expand(&1, __CALLER__))
          )

        merged_opts = Keyword.put(merged_opts, :source_module, source_module)

        define(merged_opts)
      end

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
    end
  end

  defmacro __before_compile__(env) do
    module = env.module

    opts = Module.get_attribute(module, :opts)
    enabled_extensions = Module.get_attribute(module, :enabled_extensions)
    custom_steps = Module.get_attribute(module, :steps, [])

    extension_steps = Enum.map(enabled_extensions, fn extension -> extension.steps() end)

    source_module_steps =
      case opts[:source_module] do
        nil ->
          []

        source_module ->
          if function_exported?(source_module, :steps, 0) do
            [source_module.steps()]
          else
            []
          end
      end

    Enum.each(enabled_extensions, fn extension ->
      uow = extension.unit_of_work(Module.get_attribute(module, :unit_of_work), opts)
      Module.put_attribute(module, :unit_of_work, uow)
    end)

    quote do
      unquote_splicing(extension_steps)
      unquote_splicing(source_module_steps)
      unquote(custom_steps)
      def __unit_of_work__, do: @unit_of_work
    end
  end

  defmacro steps(do: block) do
    quote do
      @steps unquote(Macro.escape(block))

      def steps, do: @steps
    end
  end

  def merge_opts(nil, new_opts), do: new_opts

  def merge_opts(module, new_opts) when is_atom(module) and is_list(new_opts) do
    merge_opts(module.__opts__(), new_opts)
  end

  def merge_opts(parent_opts, new_opts) when is_list(parent_opts) and is_list(new_opts) do
    extensions =
      Keyword.get(parent_opts, :extensions, []) ++ Keyword.get(new_opts, :extensions, [])

    Keyword.merge(parent_opts, new_opts) |> Keyword.put(:extensions, extensions)
  end
end
