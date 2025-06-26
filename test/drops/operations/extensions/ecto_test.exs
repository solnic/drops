defmodule Drops.Operations.Extensions.EctoTest do
  use Drops.OperationCase, async: true

  alias Drops.Operations.Extensions.Ecto, as: EctoExtension

  describe "enabled?/1" do
    test "returns true when repo is configured" do
      opts = [repo: Drops.TestRepo]
      assert EctoExtension.enabled?(opts) == true
    end

    test "returns false when repo is nil" do
      opts = [repo: nil]
      assert EctoExtension.enabled?(opts) == false
    end

    test "returns false when repo is not configured" do
      opts = [type: :command]
      assert EctoExtension.enabled?(opts) == false
    end

    test "returns false for empty options" do
      opts = []
      assert EctoExtension.enabled?(opts) == false
    end
  end

  describe "operations with Ecto schema" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :command do
      schema(Test.Ecto.UserSchema)

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, user} -> {:ok, %{name: user.name}}
          {:error, changeset} -> {:error, changeset}
        end
      end
    end

    test "it works with an Ecto schema", %{operation: operation} do
      {:ok, %{result: result, type: :command, params: params}} =
        operation.call(%{name: "Jane Doe", email: "jane@example.com"})

      assert result == %{name: "Jane Doe"}
      assert params == %{name: "Jane Doe", email: "jane@example.com"}
    end
  end

  describe "operations with custom validation" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :command do
      schema(Test.Ecto.UserSchema)

      @impl true
      def execute(params) do
        case persist(params) do
          {:ok, user} -> {:ok, %{name: user.name}}
          {:error, changeset} -> {:error, changeset}
        end
      end

      def validate(changeset) do
        changeset |> validate_required([:email])
      end
    end

    test "it works with an Ecto schema and custom validation logic", %{
      operation: operation
    } do
      {:ok, %{result: result, type: :command, params: params}} =
        operation.call(%{
          name: "Jane Doe",
          email: "jane@example.com"
        })

      assert result == %{name: "Jane Doe"}
      assert params == %{name: "Jane Doe", email: "jane@example.com"}

      {:error, %{result: changeset, type: :command, params: _params}} =
        operation.call(%{name: "Jane Doe", email: ""})

      # Verify that the changeset has validation errors for email
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
      assert changeset.errors[:email]
    end
  end

  describe "operations with schema merging" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :command do
      schema(Test.Ecto.UserSchema) do
        %{
          optional(:extra_field) => string()
        }
      end

      @impl true
      def execute(%{changeset: changeset, params: original_params}) do
        # Get the validated Ecto fields from changeset.changes
        ecto_fields = changeset.changes

        # Merge them, giving priority to validated Ecto fields
        result = Map.merge(original_params, ecto_fields)

        {:ok, result}
      end

      def validate(changeset) do
        changeset
      end

      # Override changeset to include original params
      def changeset(%{params: params} = context) do
        # Only cast Ecto fields, but preserve original params
        ecto_params = Map.drop(params, [:extra_field])

        changeset =
          %Test.Ecto.UserSchema{}
          |> cast(ecto_params, [:name, :email])
          |> validate_required([:name, :email])

        # Return updated context with changeset
        Map.put(context, :changeset, changeset)
      end
    end

    test "it merges Ecto schema with block schema", %{operation: operation} do
      {:ok, %{result: result, type: :command, params: params}} =
        operation.call(%{
          name: "Jane Doe",
          email: "jane@example.com",
          extra_field: "extra_value"
        })

      # Should include both Ecto schema fields and block fields
      assert params[:name] == "Jane Doe"
      assert params[:email] == "jane@example.com"
      assert params[:extra_field] == "extra_value"
      assert result == params
    end

    test "it works without the optional block field", %{operation: operation} do
      {:ok, %{result: result, type: :command, params: params}} =
        operation.call(%{
          name: "Jane Doe",
          email: "jane@example.com"
        })

      # Should include Ecto schema fields, extra_field should be nil
      assert params[:name] == "Jane Doe"
      assert params[:email] == "jane@example.com"
      assert params[:extra_field] == nil
      assert result == params
    end
  end

  describe "operations with accept option" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :command do
      schema(Test.Ecto.UserSchema, accept: [:name])

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, user} -> {:ok, %{name: user.name, email: user.email}}
          {:error, changeset} -> {:error, changeset}
        end
      end

      def validate(changeset) do
        changeset
      end
    end

    test "it works with an Ecto schema and :accept option", %{operation: operation} do
      {:ok, %{result: result, type: :command, params: params}} =
        operation.call(%{
          name: "Jane Doe",
          email: "jane@example.com"
        })

      assert result == %{name: "Jane Doe", email: nil}
      assert params == %{name: "Jane Doe"}
    end
  end

  describe "operations with embedded schemas" do
    @tag ecto_schemas: [Test.Ecto.UserWithAddressSchema]
    operation type: :command do
      schema(Test.Ecto.UserWithAddressSchema)

      @impl true
      def execute(params) do
        case persist(params) do
          {:ok, user} -> {:ok, %{name: user.name, address: user.address}}
          {:error, changeset} -> {:error, changeset}
        end
      end
    end

    test "it works with an Ecto schema with embedded fields", %{operation: operation} do
      # Test with valid embedded data
      valid_params = %{
        name: "John Doe",
        email: "john@example.com",
        address: %{
          street: "123 Main St",
          city: "Anytown",
          state: "CA",
          zip_code: "12345",
          country: "USA"
        }
      }

      {:ok, %{result: result, type: :command, params: params}} =
        operation.call(valid_params)

      assert result.name == "John Doe"
      assert result.address.street == "123 Main St"
      assert result.address.city == "Anytown"
      assert params == valid_params
    end
  end

  describe "prepare/1 with Ecto schema" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :command do
      schema(Test.Ecto.UserSchema)

      @impl true
      def prepare(%{params: params} = context) do
        updated_params =
          case params do
            %{email: email} when is_binary(email) ->
              Map.put(params, :email, String.downcase(email))

            _ ->
              params
          end

        Map.put(context, :params, updated_params)
      end

      @impl true
      def validate(changeset) do
        changeset
        |> validate_required([:name, :email])
        |> validate_format(:email, ~r/@/)
      end

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, user} -> {:ok, %{id: user.id, name: user.name, email: user.email}}
          {:error, changeset} -> {:error, changeset}
        end
      end
    end

    test "it calls prepare/1 before validation", %{operation: operation} do
      {:ok, %{result: result, type: :command, params: params}} =
        operation.call(%{
          name: "Jane Doe",
          email: "JANE@EXAMPLE.COM"
        })

      # Email should be downcased by prepare/1
      assert result.email == "jane@example.com"
      assert params.email == "jane@example.com"
    end
  end

  describe "operations with cast/1 and schema merging" do
    @tag ecto_schemas: [Test.Ecto.UserGroupSchemas.User, Test.Ecto.UserGroupSchemas.Group]
    operation type: :command do
      import Ecto.Changeset
      import Ecto.Query

      schema(Test.Ecto.UserGroupSchemas.User) do
        %{
          optional(:group_ids) => list(integer())
        }
      end

      @impl true
      def execute(%{changeset: changeset}) do
        case Drops.TestRepo.insert(changeset) do
          {:ok, user} ->
            user_with_groups = Drops.TestRepo.preload(user, :groups)

            {:ok,
             %{
               id: user_with_groups.id,
               name: user_with_groups.name,
               groups: user_with_groups.groups
             }}

          {:error, changeset} ->
            {:error, changeset}
        end
      end

      @impl true
      def cast_changeset(params, changeset) do
        group_ids = params[:group_ids]

        groups =
          if length(group_ids) > 0 do
            from(g in Test.Ecto.UserGroupSchemas.Group, where: g.id in ^group_ids)
            |> Drops.TestRepo.all()
          else
            []
          end

        changeset |> put_assoc(:groups, groups)
      end

      # Override changeset to exclude virtual fields like group_ids
      def changeset(%{params: params} = context) do
        # Filter out virtual fields that aren't part of the Ecto schema
        ecto_params = Map.drop(params, [:group_ids])

        changeset =
          %Test.Ecto.UserGroupSchemas.User{}
          |> cast(ecto_params, [:name, :email])
          |> validate_required([:name, :email])

        # Return updated context with changeset
        Map.put(context, :changeset, changeset)
      end
    end

    test "it works with empty group_ids", %{operation: operation} do
      {:ok, %{result: result, type: :command, params: params}} =
        operation.call(%{
          name: "John Doe",
          email: "john@example.com",
          group_ids: []
        })

      # Verify the user was created without groups
      assert result.name == "John Doe"
      assert result.groups == []
      assert params[:group_ids] == []
    end
  end

  describe ":form commands - changeset validation" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :form do
      schema(Test.Ecto.UserSchema, default_presence: :optional)

      @impl true
      def execute(params) do
        {:ok, params}
      end

      def validate(changeset) do
        changeset |> validate_required([:name])
      end
    end

    test "Form command with changeset validation errors", %{operation: operation} do
      # Only run this test if Phoenix.HTML is available
      case Code.ensure_loaded(Phoenix.HTML.FormData) do
        {:module, _} ->
          # Test with data that passes schema validation but fails changeset validation (using string keys like real forms)
          # Omit name field to pass schema validation but fail changeset validation
          {:error, failure} =
            operation.call(%{
              "email" => "jane@example.com"
            })

          form = Phoenix.HTML.FormData.to_form(failure, [])
          assert is_struct(form)

          assert %Ecto.Changeset{} = form.source
          assert form.errors[:name] == {"can't be blank", [validation: :required]}

        {:error, _} ->
          :ok
      end
    end
  end

  describe ":form commands - schema validation" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :form do
      schema(Test.Ecto.UserSchema)

      @impl true
      def execute(params) do
        {:ok, params}
      end
    end

    test "Form command with schema validation errors converts to changeset for FormData",
         %{
           operation: operation
         } do
      # Only run this test if Phoenix.HTML is available
      case Code.ensure_loaded(Phoenix.HTML.FormData) do
        {:module, _} ->
          # Test with invalid data that fails schema validation (using string keys like real forms)
          # Missing "email" field will cause schema validation to fail
          {:error, failure} =
            operation.call(%{
              "name" => "John Doe"
            })

          # Test that Failure struct with schema errors can be converted to a form
          form = Phoenix.HTML.FormData.to_form(failure, [])
          assert is_struct(form)

          # The form should use a changeset with converted errors
          assert %Ecto.Changeset{} = form.source
          assert form.errors[:email] == {"key must be present", []}

        {:error, _} ->
          # Skip test if Phoenix.HTML is not available
          :ok
      end
    end
  end

  describe ":form commands - changeset failures" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :form do
      schema(Test.Ecto.UserSchema)

      @impl true
      def execute(%{changeset: changeset}) do
        # Add error to the changeset to test error handling
        invalid_changeset =
          changeset
          |> Ecto.Changeset.add_error(:name, "is required")
          |> Map.put(:action, :validate)

        {:error, invalid_changeset}
      end
    end

    test "Failure struct with Ecto.Changeset implements Phoenix.HTML.FormData protocol",
         %{
           operation: operation
         } do
      # Only run this test if Phoenix.HTML is available
      case Code.ensure_loaded(Phoenix.HTML.FormData) do
        {:module, _} ->
          {:error, failure} =
            operation.call(%{
              "name" => "",
              "email" => "jane@example.com"
            })

          # Test that Failure struct with changeset can be converted to a form
          form = Phoenix.HTML.FormData.to_form(failure, [])
          assert is_struct(form)

          # The form should use the changeset data
          assert %Ecto.Changeset{} = form.source

          # Test that errors are preserved
          assert form.errors[:name] == {"is required", []}

        {:error, _} ->
          # Skip test if Phoenix.HTML is not available
          :ok
      end
    end
  end

  describe ":form commands - failure cases" do
    @tag ecto_schemas: [Test.Ecto.UserSchema]
    operation type: :form do
      schema(Test.Ecto.UserSchema)

      @impl true
      def execute(_params) do
        {:error, "Something went wrong"}
      end
    end

    test "Failure struct implements Phoenix.HTML.FormData protocol", %{
      operation: operation
    } do
      # Only run this test if Phoenix.HTML is available
      case Code.ensure_loaded(Phoenix.HTML.FormData) do
        {:module, _} ->
          {:error, failure} =
            operation.call(%{
              "name" => "Jane Doe",
              "email" => "jane@example.com"
            })

          # Test that Failure struct can be converted to a form
          form = Phoenix.HTML.FormData.to_form(failure, [])
          assert is_struct(form)
          assert form.data == %{"name" => "Jane Doe", "email" => "jane@example.com"}

          # Test input_value function
          assert Phoenix.HTML.FormData.input_value(failure, form, :name) == "Jane Doe"

          assert Phoenix.HTML.FormData.input_value(failure, form, :email) ==
                   "jane@example.com"

        {:error, _} ->
          # Skip test if Phoenix.HTML is not available
          :ok
      end
    end
  end

  describe ":form commands" do
    @describetag ecto_schemas: [Test.Ecto.UserSchema]

    operation type: :form do
      schema(Test.Ecto.UserSchema)

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, user} -> {:ok, %{name: user.name}}
          {:error, changeset} -> {:error, changeset}
        end
      end

      def validate(changeset) do
        changeset
      end
    end

    test "it works with an Ecto schema", %{operation: operation} do
      {:ok, %{result: result, type: :form, params: params}} =
        operation.call(%{
          "name" => "Jane Doe",
          "email" => "jane@example.com"
        })

      assert result == %{name: "Jane Doe"}
      assert params == %{name: "Jane Doe", email: "jane@example.com"}
    end

    test "Success struct implements Phoenix.HTML.FormData protocol", %{
      operation: operation
    } do
      # Only run this test if Phoenix.HTML is available
      case Code.ensure_loaded(Phoenix.HTML.FormData) do
        {:module, _} ->
          {:ok, success} =
            operation.call(%{
              "name" => "Jane Doe",
              "email" => "jane@example.com"
            })

          # Test that Success struct can be converted to a form
          form = Phoenix.HTML.FormData.to_form(success, [])
          assert is_struct(form)
          assert form.data == %{"name" => "Jane Doe", "email" => "jane@example.com"}

          # Test input_value function
          assert Phoenix.HTML.FormData.input_value(success, form, :name) == "Jane Doe"

          assert Phoenix.HTML.FormData.input_value(success, form, :email) ==
                   "jane@example.com"

        {:error, _} ->
          # Skip test if Phoenix.HTML is not available
          :ok
      end
    end
  end
end
