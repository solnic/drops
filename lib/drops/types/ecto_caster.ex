defmodule Drops.Types.EctoCaster do
  @moduledoc """
  Type that safely handles Ecto type casting.

  This type wraps Ecto's casting functionality and provides proper error handling
  that integrates with the Drops validation system.
  """

  use Drops.Type do
    deftype(:any, ecto_type: nil, ecto_schema: nil)
  end

  alias Drops.Type.Validator

  def new(ecto_type, ecto_schema) do
    struct(__MODULE__, ecto_type: ecto_type, ecto_schema: ecto_schema)
  end

  defimpl Validator, for: __MODULE__ do
    def validate(%{ecto_type: ecto_type, ecto_schema: _ecto_schema}, value) do
      case Ecto.Type.cast(ecto_type, value) do
        {:ok, casted_value} ->
          {:ok, casted_value}

        :error ->
          {:error, {:cast, [predicate: :cast, args: ["has unexpected value"]]}}
      end
    end
  end
end
