defmodule Drops.Operations.Extensions.Command do
  use Drops.Operations.Extension

  @callback execute(context :: map()) :: {:ok, any()} | {:error, any()}

  @impl true
  def unit_of_work(uow, _opts) do
    uow
    |> add_step(:prepare)
    |> add_step(:validate)
    |> add_step(:execute)
  end

  def using do
    quote do
      @behaviour Drops.Operations.Extensions.Command
    end
  end

  steps do
    def prepare(context) do
      {:ok, context}
    end

    def validate(context) do
      {:ok, context}
    end

    @impl true
    def execute(_context) do
      raise "#{__MODULE__}.execute/1 must be implemented"
    end

    defoverridable prepare: 1, validate: 1, execute: 1
  end
end
