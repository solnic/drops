defmodule Drops.Operations.Extension do
  @callback enable?(opts :: keyword()) :: boolean()

  @callback unit_of_work(uow :: map(), opts :: keyword()) :: map()

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
