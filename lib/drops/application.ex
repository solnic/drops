defmodule Drops.Application do
  @moduledoc false

  use Application

  alias Drops.Config

  @impl true
  def start(_type, _opts) do
    # Ensure built-in extensions are available in app env before validation
    ensure_builtin_extensions_in_app_env()

    config = Config.validate!()
    :ok = Config.persist(config)

    register_builtin_types()

    register_builtin_extensions(config)

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

  defp ensure_builtin_extensions_in_app_env do
    builtin_extensions = [
      Drops.Operations.Extensions.Ecto
    ]

    # Get current extensions from app env
    current_extensions = Application.get_env(:drops, :registered_extensions, [])

    # Add built-in extensions if not already present
    updated_extensions =
      builtin_extensions
      |> Enum.reduce(current_extensions, fn ext, acc ->
        if ext in acc, do: acc, else: [ext | acc]
      end)

    # Update app env if changed
    if updated_extensions != current_extensions do
      Application.put_env(:drops, :registered_extensions, updated_extensions)
    end
  end

  defp register_builtin_extensions(_config) do
    builtin_extensions = [
      Drops.Operations.Extensions.Ecto
    ]

    Enum.each(builtin_extensions, &Drops.Operations.Extension.register_extension/1)
  end
end
