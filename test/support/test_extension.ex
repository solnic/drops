defmodule Test.Extensions do
  defmodule PrepareExtension do
    @behaviour Drops.Operations.Extension

    @impl true
    def enabled?(_opts) do
      true
    end

    @impl true
    def extend_operation(_opts) do
      quote do
        def prepare(%{params: params} = context) do
          updated_params =
            if Map.has_key?(params, :name) do
              Map.put(params, :name, "prepared_" <> params.name)
            else
              params
            end

          {:ok, Map.put(context, :params, updated_params)}
        end
      end
    end

    @impl true
    def extend_unit_of_work(uow, _opts) do
      uow
    end
  end

  defmodule ValidateExtension do
    @behaviour Drops.Operations.Extension

    @impl true
    def enabled?(_opts) do
      true
    end

    @impl true
    def extend_operation(_opts) do
      quote do
        def validate(%{params: params} = context) do
          if Map.has_key?(params, :name) and String.contains?(params.name, "invalid") do
            {:error, "name cannot contain 'invalid'"}
          else
            {:ok, context}
          end
        end
      end
    end

    @impl true
    def extend_unit_of_work(uow, _opts) do
      uow
    end
  end
end
