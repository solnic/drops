defmodule Drops.Types.EctoCaster do
  @moduledoc """
  Custom caster that delegates to Ecto's type casting.
  """

  def cast(_input_type, _output_type, value, caster_opt, ecto_type_opt, ecto_schema_opt) do
    {:caster, _} = caster_opt
    {:ecto_type, ecto_type} = ecto_type_opt
    {:ecto_schema, ecto_schema} = ecto_schema_opt

    case Ecto.Type.cast(ecto_type, value) do
      {:ok, casted_value} ->
        casted_value

      :error ->
        raise ArgumentError,
              "cannot cast #{inspect(value)} to #{inspect(ecto_type)} for schema #{inspect(ecto_schema)}"
    end
  end
end
