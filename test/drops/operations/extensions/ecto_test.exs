defmodule Drops.Operations.Extensions.EctoTest do
  use Drops.OperationCase, async: false

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
    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, user} -> {:ok, %{name: user.name}}
          {:error, changeset} -> {:error, changeset}
        end
      end
    end

    test "it works with an Ecto schema", %{operation: operation} do
      {:ok, result} =
        operation.call(%{params: %{name: "Jane Doe", email: "jane@example.com"}})

      assert result == %{name: "Jane Doe"}
    end
  end

  describe "operations with casting and type coercion" do
    @tag ecto_schemas: [Test.Ecto.TestSchemas.CastingTestSchema]
    operation type: :command do
      schema(Test.Ecto.TestSchemas.CastingTestSchema,
        cast: true,
        field_presence: %{admin: :optional, age: :optional, score: :optional}
      )

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, record} ->
            {:ok,
             %{
               name: record.name,
               admin: record.admin,
               age: record.age,
               score: record.score
             }}

          {:error, changeset} ->
            {:error, changeset}
        end
      end
    end

    test "it casts boolean fields correctly from strings", %{operation: operation} do
      # Test with string "true" -> boolean true
      {:ok, result} =
        operation.call(%{
          params: %{name: "Admin User", admin: "true"}
        })

      assert result == %{name: "Admin User", admin: true, age: nil, score: nil}

      # Test with string "false" -> boolean false
      {:ok, result} =
        operation.call(%{
          params: %{name: "Regular User", admin: "false"}
        })

      assert result == %{name: "Regular User", admin: false, age: nil, score: nil}

      # Test with actual boolean values
      {:ok, result} =
        operation.call(%{
          params: %{name: "Bool Admin", admin: true}
        })

      assert result == %{name: "Bool Admin", admin: true, age: nil, score: nil}
    end

    test "it casts integer fields correctly from strings", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "User", age: "25"}
        })

      assert result == %{name: "User", admin: false, age: 25, score: nil}
    end

    test "it casts float fields correctly from strings", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "User", score: "98.5"}
        })

      assert result == %{name: "User", admin: false, age: nil, score: 98.5}
    end
  end

  describe "operations with custom validation" do
    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, user} -> {:ok, %{name: user.name}}
          {:error, changeset} -> {:error, changeset}
        end
      end

      def validate_changeset(%{changeset: changeset}) do
        changeset
        |> validate_required([:email])
        |> validate_length(:email, min: 1, message: "can't be blank")
      end
    end

    test "it works with an Ecto schema and custom validation logic", %{
      operation: operation
    } do
      {:ok, result} =
        operation.call(%{
          params: %{
            name: "Jane Doe",
            email: "jane@example.com"
          }
        })

      assert result == %{name: "Jane Doe"}

      {:error, changeset} = operation.call(%{params: %{name: "Jane Doe", email: ""}})

      # Verify that the changeset has validation errors for email
      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
      assert changeset.errors[:email]
    end
  end

  describe "operations with accept option" do
    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema, accept: [:name])

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, user} -> {:ok, %{name: user.name, email: user.email}}
          {:error, changeset} -> {:error, changeset}
        end
      end

      def validate(context) do
        changeset = Map.get(context, :changeset)
        Map.put(context, :changeset, changeset)
      end
    end

    test "it works with an Ecto schema and :accept option", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{
            name: "Jane Doe",
            email: "jane@example.com"
          }
        })

      assert result == %{name: "Jane Doe", email: nil}
    end
  end

  describe "operations with embedded schemas" do
    @tag ecto_schemas: [Test.Ecto.UserWithAddressSchema]
    operation type: :command do
      schema(Test.Ecto.UserWithAddressSchema)

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
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

      {:ok, result} = operation.call(%{params: valid_params})

      assert result.name == "John Doe"
      assert result.address.street == "123 Main St"
      assert result.address.city == "Anytown"
    end
  end

  describe "prepare/1 with Ecto schema" do
    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      @impl true
      def prepare(%{params: params} = context) do
        updated_params =
          case params do
            %{email: email} when is_binary(email) ->
              Map.put(params, :email, String.downcase(email))

            _ ->
              params
          end

        {:ok, Map.put(context, :params, updated_params)}
      end

      @impl true
      def validate_changeset(%{changeset: changeset}) do
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
      {:ok, result} =
        operation.call(%{
          params: %{
            name: "Jane Doe",
            email: "JANE@EXAMPLE.COM"
          }
        })

      # Email should be downcased by prepare/1
      assert result.email == "jane@example.com"
    end
  end

  describe "operations with group associations" do
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
      def prepare(%{params: params} = context) do
        group_ids = Map.get(params, :group_ids, [])

        # Fetch groups from the database
        groups =
          if length(group_ids) > 0 do
            from(g in Test.Ecto.UserGroupSchemas.Group, where: g.id in ^group_ids)
            |> Drops.TestRepo.all()
          else
            []
          end

        # Remove group_ids from params and add groups to context
        updated_params = Map.drop(params, [:group_ids])

        updated_context =
          context
          |> Map.put(:params, updated_params)
          |> Map.put(:groups, groups)

        {:ok, updated_context}
      end

      @impl true
      def execute(%{changeset: changeset, groups: groups}) do
        # Add groups to the changeset
        changeset_with_groups = put_assoc(changeset, :groups, groups)

        case Drops.TestRepo.insert(changeset_with_groups) do
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
    end

    test "it works with empty group_ids", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{
            name: "John Doe",
            email: "john@example.com",
            group_ids: []
          }
        })

      # Verify the user was created without groups
      assert result.name == "John Doe"
      assert result.groups == []
    end
  end

  describe ":form commands - changeset validation" do
    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    operation type: :form do
      schema(Test.Ecto.TestSchemas.UserSchema, default_presence: :optional)

      @impl true
      def execute(%{changeset: changeset, params: params}) do
        # For form commands, we typically return the params but validate via changeset
        if changeset.valid? do
          {:ok, params}
        else
          {:error, changeset}
        end
      end

      def validate_changeset(%{changeset: changeset}) do
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
              params: %{
                "email" => "jane@example.com"
              }
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
    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    operation type: :form do
      schema(Test.Ecto.TestSchemas.UserSchema)

      @impl true
      def execute(context) do
        params = Map.get(context, :params)
        {:ok, params}
      end
    end

    test "Form command with schema validation errors returns error list directly",
         %{
           operation: operation
         } do
      # Test with invalid data that fails schema validation (using string keys like real forms)
      # Missing "email" field will cause schema validation to fail
      {:error, errors} =
        operation.call(%{
          params: %{
            "name" => "John Doe"
          }
        })

      # Test that operation returns schema validation errors directly (new idiomatic format)
      assert is_list(errors)
      assert length(errors) == 1

      error = List.first(errors)
      assert %Drops.Validator.Messages.Error.Type{} = error
      assert error.path == [:email]
      assert error.text == "key must be present"
    end
  end

  describe ":form commands - changeset failures" do
    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    operation type: :form do
      schema(Test.Ecto.TestSchemas.UserSchema)

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
              params: %{
                "name" => "",
                "email" => "jane@example.com"
              }
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
    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    operation type: :form do
      schema(Test.Ecto.TestSchemas.UserSchema)

      @impl true
      def execute(_context) do
        {:error, "Something went wrong"}
      end
    end

    test "Operation returns error result directly", %{
      operation: operation
    } do
      {:error, error_result} =
        operation.call(%{
          params: %{
            "name" => "Jane Doe",
            "email" => "jane@example.com"
          }
        })

      # Test that operation returns error result directly (new idiomatic format)
      assert error_result == "Something went wrong"
    end
  end

  describe ":form commands" do
    @describetag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]

    operation type: :form do
      schema(Test.Ecto.TestSchemas.UserSchema)

      @impl true
      def execute(%{changeset: changeset}) do
        case persist(changeset) do
          {:ok, user} -> {:ok, %{name: user.name}}
          {:error, changeset} -> {:error, changeset}
        end
      end
    end

    test "it works with an Ecto schema", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{
            "name" => "Jane Doe",
            "email" => "jane@example.com"
          }
        })

      assert result == %{name: "Jane Doe"}
    end

    test "Operation returns success result directly", %{
      operation: operation
    } do
      {:ok, result} =
        operation.call(%{
          params: %{
            "name" => "Jane Doe",
            "email" => "jane@example.com"
          }
        })

      # Test that operation returns result directly (new idiomatic format)
      assert result == %{name: "Jane Doe"}
    end
  end
end
