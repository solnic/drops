defmodule Drops.Application do
  @moduledoc false

  use Application

  alias Drops.Config

  @impl true
  def start(_type, _opts) do
    config = Config.validate!()
    :ok = Config.persist(config)

    register_builtin_types()

    children = []

    opts = [strategy: :one_for_one, name: Drops.Supervisor]
    Supervisor.start_link(children, opts)
  end

  defp register_builtin_types do
    builtin_types = [
      Drops.Types.Cast,
      Drops.Types.List,
      Drops.Types.Map,
      Drops.Types.Number,
      Drops.Types.Primitive,
      Drops.Types.Union
    ]

    Enum.each(builtin_types, &Drops.Type.register_type/1)
  end
end
