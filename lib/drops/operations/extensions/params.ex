defmodule Drops.Operations.Extensions.Params do
  use Drops.Operations.Extension

  def using do
    quote do
      use Drops.Contract

      @schema_opts Keyword.get(@opts, :schema, [])

      schema do
        %{}
      end

      def conform(%{params: params} = context) do
        case super(params) do
          {:ok, conformed_params} ->
            {:ok, Map.put(context, :params, conformed_params)}

          {:error, _} = error ->
            error
        end
      end
    end
  end

  @impl true
  def unit_of_work(uow, _opts) do
    schemas = Module.get_attribute(uow.module, :schemas)
    schema = schemas[:default]

    if not is_nil(schema) and schema.keys != [] do
      before_step(uow, :prepare, :conform)
    else
      uow
    end
  end
end
