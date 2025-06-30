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

        def prepare_more(%{params: params} = context) do
          {:ok, Map.put(context, :params, Map.put(params, :prepared, true))}
        end
      end
    end

    @impl true
    def extend_unit_of_work(uow, _mod, _opts) do
      Drops.Operations.UnitOfWork.after_step(uow, :prepare, :prepare_more)
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
  end

  defmodule StepExtension do
    @behaviour Drops.Operations.Extension

    @impl true
    def enabled?(_opts) do
      true
    end

    @impl true
    def extend_operation(_opts) do
      quote do
        def log_before_prepare(context) do
          Process.put(:before_prepare_called, true)
          {:ok, Map.put(context, :before_prepare_called, true)}
        end

        def log_after_prepare(context) do
          {:ok, Map.put(context, :after_prepare_called, true)}
        end
      end
    end

    @impl true
    def extend_unit_of_work(uow, _mod, _opts) do
      uow
      |> Drops.Operations.UnitOfWork.before_step(:prepare, :log_before_prepare)
      |> Drops.Operations.UnitOfWork.after_step(:prepare, :log_after_prepare)
    end
  end
end
