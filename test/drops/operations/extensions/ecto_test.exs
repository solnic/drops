defmodule Drops.Operations.Extensions.EctoTest do
  use Drops.OperationCase, async: false

  describe "operations with Ecto schema" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{name: user.name}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "it works with an Ecto schema", %{operation: operation} do
      {:ok, result} =
        operation.call(%{params: %{name: "Jane Doe", email: "jane@example.com"}})

      assert result == %{name: "Jane Doe"}
    end
  end

  describe "operations with casting and type coercion" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.CastingTestSchema,
        field_presence: %{admin: :optional, age: :optional, score: :optional}
      )

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
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
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.CastingTestSchema]
    test "it casts boolean fields correctly from strings", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "Admin User", admin: "true"}
        })

      assert result == %{name: "Admin User", admin: true, age: nil, score: nil}

      {:ok, result} =
        operation.call(%{
          params: %{name: "Regular User", admin: "false"}
        })

      assert result == %{name: "Regular User", admin: false, age: nil, score: nil}

      {:ok, result} =
        operation.call(%{
          params: %{name: "Bool Admin", admin: true}
        })

      assert result == %{name: "Bool Admin", admin: true, age: nil, score: nil}
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.CastingTestSchema]
    test "it casts integer fields correctly from strings", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "User", age: "25"}
        })

      assert result == %{name: "User", admin: false, age: 25, score: nil}
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.CastingTestSchema]
    test "it casts float fields correctly from strings", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "User", score: "98.5"}
        })

      assert result == %{name: "User", admin: false, age: nil, score: 98.5}
    end
  end

  describe "operations with default casting behavior" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.CastingTestSchema,
        field_presence: %{admin: :optional, age: :optional, score: :optional}
      )

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
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
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.CastingTestSchema]
    test "it automatically casts string inputs by default", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "User", age: "25", admin: "true", score: "98.5"}
        })

      assert result == %{name: "User", admin: true, age: 25, score: 98.5}
    end
  end

  describe "operations with explicit cast: false" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.CastingTestSchema,
        cast: false,
        field_presence: %{admin: :optional, age: :optional, score: :optional}
      )

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
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
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.CastingTestSchema]
    test "it does not cast when explicitly disabled", %{operation: operation} do
      {:error, errors} =
        operation.call(%{
          params: %{name: "User", age: "25"}
        })

      assert is_list(errors)

      assert Enum.any?(errors, fn error ->
               error.path == [:age] and String.contains?(error.text, "integer")
             end)
    end
  end

  describe "operations with custom validation" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{name: user.name}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end

      @impl true
      def validate_changeset(%{changeset: changeset}) do
        changeset
        |> validate_required([:email])
        |> validate_length(:email, min: 1, message: "can't be blank")
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
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

      assert %Ecto.Changeset{} = changeset
      refute changeset.valid?
      assert changeset.errors[:email]
    end
  end

  describe "operations with accept option" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema, accept: [:name])

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{name: user.name, email: user.email}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
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
    operation type: :command do
      schema(Test.Ecto.UserWithAddressSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{name: user.name, address: user.address}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end
    end

    @tag ecto_schemas: [Test.Ecto.UserWithAddressSchema]
    test "it works with an Ecto schema with embedded fields", %{operation: operation} do
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
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def prepare(%{params: %{email: email} = params} = context) do
          {:ok, Map.put(context, :params, %{params | email: String.downcase(email)})}
        end

        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{id: user.id, name: user.name, email: user.email}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end

      @impl true
      def validate_changeset(%{changeset: changeset}) do
        changeset
        |> validate_required([:name, :email])
        |> validate_format(:email, ~r/@/)
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "it calls prepare/1 before validation", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{
            name: "Jane Doe",
            email: "JANE@EXAMPLE.COM"
          }
        })

      assert result.email == "jane@example.com"
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "returns error when conform/1 did not pass", %{operation: operation} do
      assert_errors(
        ["cast error: email has unexpected value"],
        operation.call(%{
          params: %{
            name: "Jane Doe",
            email: ["this is unexpected"]
          }
        })
      )
    end
  end

  describe "operations with group associations" do
    operation type: :command do
      import Ecto.Changeset
      import Ecto.Query

      schema(Test.Ecto.UserGroupSchemas.User) do
        %{
          optional(:group_ids) => list(integer())
        }
      end

      steps do
        @impl true
        def prepare(%{params: params} = context) do
          group_ids = Map.get(params, :group_ids, [])

          groups =
            if length(group_ids) > 0 do
              from(g in Test.Ecto.UserGroupSchemas.Group, where: g.id in ^group_ids)
              |> Drops.TestRepo.all()
            else
              []
            end

          updated_params = Map.drop(params, [:group_ids])

          updated_context =
            context
            |> Map.put(:params, updated_params)
            |> Map.put(:groups, groups)

          {:ok, updated_context}
        end

        @impl true
        def execute(%{changeset: changeset, groups: groups}) do
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
    end

    @tag ecto_schemas: [Test.Ecto.UserGroupSchemas.User, Test.Ecto.UserGroupSchemas.Group]
    test "it works with empty group_ids", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{
            name: "John Doe",
            email: "john@example.com",
            group_ids: []
          }
        })

      assert result.name == "John Doe"
      assert result.groups == []
    end
  end

  describe ":form commands - schema validation" do
    operation type: :form do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(context) do
          params = Map.get(context, :params)
          {:ok, params}
        end
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "Form command with schema validation errors returns error list directly",
         %{
           operation: operation
         } do
      {:error, errors} =
        operation.call(%{
          params: %{
            "name" => "John Doe"
          }
        })

      assert is_list(errors)
      assert length(errors) == 1

      error = List.first(errors)
      assert %Drops.Validator.Messages.Error.Type{} = error
      assert error.path == [:email]
      assert error.text == "key must be present"
    end
  end

  describe ":form commands - failure cases" do
    operation type: :form do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(_context) do
          {:error, "Something went wrong"}
        end
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
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

      assert error_result == "Something went wrong"
    end
  end

  describe ":form commands" do
    @describetag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]

    operation type: :form do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{name: user.name}}
            {:error, changeset} -> {:error, changeset}
          end
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

      assert result == %{name: "Jane Doe"}
    end
  end

  describe "Ecto behaviour callbacks" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{name: user.name, email: user.email}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end

      @impl true
      def get_struct(%{params: %{name: "Custom"}}) do
        %Test.Ecto.TestSchemas.UserSchema{name: "Default Name"}
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "allows overriding get_struct/1 callback", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "Custom", email: "custom@example.com"}
        })

      assert result == %{name: "Custom", email: "custom@example.com"}
    end
  end

  describe "get_struct/1 error handling" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(_context) do
          {:ok, %{}}
        end
      end

      @impl true
      def get_struct(_context) do
        raise "Failed to create struct"
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "handles get_struct/1 errors properly", %{operation: operation} do
      assert_raise RuntimeError, "Failed to create struct", fn ->
        operation.call(%{
          params: %{name: "Jane", email: "jane@example.com"}
        })
      end
    end
  end

  describe "default behaviour implementations" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{name: user.name, email: user.email}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "uses default get_struct/1 implementation", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "Jane", email: "jane@example.com"}
        })

      assert result == %{name: "Jane", email: "jane@example.com"}
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "uses default changeset/1 implementation", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "John", email: "john@example.com"}
        })

      assert result == %{name: "John", email: "john@example.com"}
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "uses default validate_changeset/1 implementation", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "Bob", email: "bob@example.com"}
        })

      assert result == %{name: "Bob", email: "bob@example.com"}
    end
  end

  describe "pattern matching fallbacks" do
    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          case insert(changeset) do
            {:ok, user} -> {:ok, %{name: user.name, email: user.email}}
            {:error, changeset} -> {:error, changeset}
          end
        end
      end

      @impl true
      def validate_changeset(%{changeset: %{changes: %{name: "Admin"}} = changeset}) do
        changeset
        |> validate_required([:name, :email])
        |> validate_format(:email, ~r/@/)
        |> validate_length(:name,
          min: 5,
          message: "Admin name must be at least 5 characters"
        )
      end

      def validate_changeset(%{changeset: changeset}) do
        changeset
      end

      @impl true
      def get_struct(%{params: %{name: "VIP"}}) do
        %Test.Ecto.TestSchemas.UserSchema{name: "VIP User"}
      end

      def get_struct(_) do
        struct(ecto_schema())
      end
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "uses custom get_struct for matching patterns", %{operation: operation} do
      {:ok, result} =
        operation.call(%{
          params: %{name: "VIP", email: "vip@example.com"}
        })

      assert result == %{name: "VIP", email: "vip@example.com"}
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "falls back to default get_struct for non-matching patterns", %{
      operation: operation
    } do
      {:ok, result} =
        operation.call(%{
          params: %{name: "Regular", email: "regular@example.com"}
        })

      assert result == %{name: "Regular", email: "regular@example.com"}
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "uses custom validate_changeset for matching patterns", %{operation: operation} do
      {:error, changeset} =
        operation.call(%{
          params: %{name: "Admin", email: "invalid-email"}
        })

      assert changeset.errors[:email] != nil
    end

    @tag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]
    test "falls back to default validate_changeset for non-matching patterns", %{
      operation: operation
    } do
      {:ok, result} =
        operation.call(%{
          params: %{name: "User", email: "invalid-email"}
        })

      assert result == %{name: "User", email: "invalid-email"}
    end
  end

  describe "insert/1" do
    @describetag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]

    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          insert(changeset)
        end
      end

      @impl true
      def validate_changeset(%{changeset: changeset}) do
        changeset |> validate_required([:name, :email])
      end
    end

    test "inserts a struct into the database when params are valid", %{
      operation: operation
    } do
      assert {:ok, user} =
               operation.call(%{params: %{name: "Jane", email: "jane@example.com"}})

      assert user.name == "Jane"
      assert user.email == "jane@example.com"
    end

    test "returns changeset with errors when params are invalid", %{
      operation: operation
    } do
      assert {:error, changeset} =
               operation.call(%{params: %{name: "Jane", email: ""}})

      assert changeset.errors[:email] != nil
    end
  end

  describe "update/1" do
    @describetag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]

    operation type: :command do
      schema(Test.Ecto.TestSchemas.UserSchema)

      steps do
        @impl true
        def execute(%{changeset: changeset}) do
          update(changeset)
        end
      end

      @impl true
      def get_struct(%{id: id}) do
        repo().get!(Test.Ecto.TestSchemas.UserSchema, id)
      end

      @impl true
      def validate_changeset(%{changeset: changeset}) do
        changeset |> validate_required([:name, :email])
      end
    end

    setup do
      user =
        Drops.TestRepo.insert!(%Test.Ecto.TestSchemas.UserSchema{
          name: "John",
          email: "john@example.com"
        })

      %{user: user}
    end

    test "updates a struct in the database when params are valid", %{
      operation: operation,
      user: user
    } do
      assert {:ok, user} =
               operation.call(%{
                 id: user.id,
                 params: %{name: "Jane", email: "jane@example.com"}
               })

      assert user.name == "Jane"
      assert user.email == "jane@example.com"
    end

    test "returns changeset with errors when params are invalid", %{
      operation: operation,
      user: user
    } do
      assert {:error, changeset} =
               operation.call(%{id: user.id, params: %{name: "Jane", email: ""}})

      assert changeset.errors[:email] != nil
    end
  end

  describe "defining abstract operation with common helpers" do
    @describetag ecto_schemas: [Test.Ecto.TestSchemas.UserSchema]

    alias Test.Ecto.TestSchemas.UserSchema

    defmodule Test.Commands do
      use Drops.Operations.Command, repo: Drops.TestRepo
    end

    defmodule Test.Commands.Save do
      use Test.Commands

      steps do
        @impl true
        def execute(%{changeset: changeset, id: nil}) do
          insert(changeset)
        end

        def execute(%{changeset: changeset, id: id}) when not is_nil(id) do
          update(changeset)
        end

        def execute(%{changeset: changeset}) do
          insert(changeset)
        end

        @impl true
        def get_struct(%{id: id}) do
          repo().get!(Test.Ecto.TestSchemas.UserSchema, id)
        end
      end
    end

    defmodule Test.Users.Save do
      use Test.Commands.Save

      schema(UserSchema)
    end

    test "derived command saves a new struct" do
      assert {:ok, user} =
               Test.Users.Save.call(%{
                 params: %{name: "Jane", email: "jane@example.com"}
               })

      assert user.name == "Jane"
      assert user.email == "jane@example.com"
    end
  end
end
