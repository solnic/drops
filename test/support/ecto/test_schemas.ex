defmodule Test.Ecto.TestSchemas do
  defmodule UserSchema do
    use Ecto.Schema
    import Ecto.Changeset

    schema "users" do
      field(:name, :string)
      field(:email, :string)

      timestamps()
    end

    def changeset(user, attrs) do
      user
      |> cast(attrs, [:name, :email])
      |> validate_required([:name])
    end
  end

  defmodule BasicTypesSchema do
    use Ecto.Schema

    schema "basic_types" do
      field(:string_field, :string)
      field(:integer_field, :integer)
      field(:float_field, :float)
      field(:boolean_field, :boolean)
      field(:binary_field, :binary)
      field(:bitstring_field, :bitstring)
    end
  end

  defmodule IdTypesSchema do
    use Ecto.Schema

    schema "id_types" do
      field(:id_field, :id)
      field(:binary_id_field, :binary_id)
    end
  end

  defmodule DateTimeTypesSchema do
    use Ecto.Schema

    schema "datetime_types" do
      field(:date_field, :date)
      field(:time_field, :time)
      field(:time_usec_field, :time_usec)
      field(:naive_datetime_field, :naive_datetime)
      field(:naive_datetime_usec_field, :naive_datetime_usec)
      field(:utc_datetime_field, :utc_datetime)
      field(:utc_datetime_usec_field, :utc_datetime_usec)
    end
  end

  defmodule NumericTypesSchema do
    use Ecto.Schema

    schema "numeric_types" do
      field(:decimal_field, :decimal)
      field(:integer_field, :integer)
      field(:float_field, :float)
    end
  end

  defmodule ArrayTypesSchema do
    use Ecto.Schema

    schema "array_types" do
      field(:string_array, {:array, :string})
      field(:integer_array, {:array, :integer})
      field(:float_array, {:array, :float})
      field(:boolean_array, {:array, :boolean})
      field(:date_array, {:array, :date})
    end
  end

  defmodule MapTypesSchema do
    use Ecto.Schema

    schema "map_types" do
      field(:map_field, :map)
      field(:typed_map_field, {:map, :string})
    end
  end

  defmodule CustomTypesSchema do
    use Ecto.Schema

    schema "custom_types" do
      field(:uuid_field, Ecto.UUID)
      field(:enum_field, Ecto.Enum, values: [:active, :inactive, :pending])
    end
  end

  defmodule EmbeddedTypesSchema do
    use Ecto.Schema

    embedded_schema do
      field(:name, :string)
      field(:value, :integer)
    end
  end

  defmodule AssociationsSchema do
    use Ecto.Schema

    schema "associations" do
      field(:name, :string)
      has_many(:items, AssociationItemSchema)
      belongs_to(:parent, AssociationParentSchema)
    end
  end

  defmodule AssociationItemSchema do
    use Ecto.Schema

    schema "association_items" do
      field(:title, :string)
      belongs_to(:association, AssociationsSchema)
    end
  end

  defmodule AssociationParentSchema do
    @moduledoc "Schema for association parent"
    use Ecto.Schema

    schema "association_parents" do
      field(:description, :string)
      has_many(:associations, AssociationsSchema)
    end
  end

  defmodule VirtualFieldsSchema do
    use Ecto.Schema

    schema "virtual_fields" do
      field(:name, :string)
      field(:computed_value, :string, virtual: true)
      field(:any_virtual, :any, virtual: true)
    end
  end

  defmodule TimestampsSchema do
    use Ecto.Schema

    schema "timestamps" do
      field(:name, :string)
      timestamps()
    end
  end

  defmodule CustomPrimaryKeySchema do
    use Ecto.Schema

    @primary_key {:uuid, :binary_id, autogenerate: true}
    schema "custom_pk" do
      field(:name, :string)
    end
  end

  defmodule NoPrimaryKeySchema do
    use Ecto.Schema

    @primary_key false
    schema "no_pk" do
      field(:name, :string)
      field(:value, :integer)
    end
  end

  defmodule CompositePrimaryKeySchema do
    use Ecto.Schema

    @primary_key false
    schema "composite_pk" do
      field(:part1, :string, primary_key: true)
      field(:part2, :integer, primary_key: true)
      field(:data, :string)
    end
  end
end
