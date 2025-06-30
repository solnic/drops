defmodule Drops.Contract do
  @moduledoc """
  Drops.Contract can be used to extend your module with data validation capabilities.
  """
  @moduledoc since: "0.1.0"

  alias Drops.Types
  alias Drops.Validator.Messages

  @doc ~S"""
  Validates the given `data` against the schema defined in the module.

  Returns `{:ok, validated_data}`.

  ## Examples

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       name: type(:string),
      ...>       age: type(:integer)
      ...>     }
      ...>   end
      ...> end
      iex> {:error, errors} = UserContract.conform("oops")
      iex> Enum.map(errors, &to_string/1)
      ["must be a map"]
      iex> UserContract.conform(%{name: "Jane", age: 48})
      {:ok, %{name: "Jane", age: 48}}
      iex> {:error, errors} = UserContract.conform(%{name: "Jane", age: "not an integer"})
      iex> Enum.map(errors, &to_string/1)
      ["age must be an integer"]

  """
  @doc since: "0.1.0"
  @callback conform(data :: map()) :: {:ok, map()} | {:error, list()}

  defmacro __using__(opts) do
    quote do
      import Drops.Contract
      import Drops.Type.DSL
      import Drops.Predicates.Helpers, only: [ok?: 1]

      @behaviour Drops.Contract

      @message_backend unquote(opts[:message_backend]) || Messages.DefaultBackend

      Module.register_attribute(__MODULE__, :rules, accumulate: true)

      @before_compile Drops.Contract

      @impl true
      def conform(data) do
        conform(data, schema(), path: [])
      end

      def conform(data, %Types.Map{} = schema, path: path) do
        case Drops.Type.Validator.validate(schema, data) do
          {outcome, {:map, items}} = result ->
            output = to_output(result)
            errors = if outcome == :ok, do: [], else: Enum.reject(items, &ok?/1)

            all_errors =
              if Enum.empty?(path), do: errors ++ apply_rules(output), else: errors

            if length(all_errors) > 0 do
              {:error, @message_backend.errors(all_errors)}
            else
              {:ok, output}
            end

          {:error, meta} ->
            {:error, @message_backend.errors({:error, {path, meta}})}
        end
      end

      def conform(data, %Types.Union{} = type, path: path) do
        case conform(data, type.left, path: path) do
          {:ok, output} = success ->
            success

          {:error, left_error} ->
            case conform(data, type.right, path: path) do
              {:ok, output} = success ->
                success

              {:error, right_error} ->
                {:error,
                 @message_backend.errors(
                   {:error, {path, {:or, {left_error, right_error, type.opts}}}}
                 )}
            end
        end
      end

      defoverridable conform: 1

      defp apply_rules(output) do
        Enum.map(rules(), fn name -> apply(__MODULE__, :rule, [name, output]) end)
        |> Enum.filter(fn
          :ok -> false
          _ -> true
        end)
      end
    end
  end

  defmacro __before_compile__(_env) do
    quote do
      def schema, do: @schemas[:default]
      def schema(name), do: @schemas[name]

      def schemas, do: @schemas

      def rules, do: @rules
    end
  end

  @doc ~S"""
  Define a default schema for the contract.

  ## Simple schema

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       name: type(:string),
      ...>       age: type(:integer)
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{name: "John", age: 21})
      {:ok, %{name: "John", age: 21}}

  ## Ecto schema inference

      iex> defmodule UserSchema do
      ...>   use Ecto.Schema
      ...>
      ...>   schema "users" do
      ...>     field(:name, :string)
      ...>     field(:email, :string)
      ...>     field(:age, :integer)
      ...>     timestamps()
      ...>   end
      ...> end
      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema(UserSchema)
      ...> end
      iex> UserContract.conform(%{name: "John", email: "john@example.com", age: 30})
      {:ok, %{name: "John", email: "john@example.com", age: 30}}

  ## Extending Ecto schema with additional fields

      iex> defmodule UserSchema do
      ...>   use Ecto.Schema
      ...>
      ...>   schema "users" do
      ...>     field(:name, :string)
      ...>     field(:email, :string)
      ...>     timestamps()
      ...>   end
      ...> end
      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema(UserSchema) do
      ...>     %{
      ...>       required(:role) => string(),
      ...>       optional(:bio) => string()
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{name: "John", email: "john@example.com", role: "admin", bio: "Developer"})
      {:ok, %{name: "John", email: "john@example.com", role: "admin", bio: "Developer"}}
  """

  # schema/1 macros
  # Handle do: block schemas (these take precedence over atom-only patterns)
  defmacro schema(do: block) do
    set_schema(__CALLER__, :default, [], block)
  end

  # Handle Ecto schema modules (module references) - MUST come after all block patterns
  defmacro schema({:__aliases__, _, _} = ecto_schema_module) do
    set_inferred_schema(__CALLER__, :default, [], ecto_schema_module)
  end

  # schema/2 macros
  # Handle named schemas with blocks - MUST come before single atom patterns
  defmacro schema(name, do: block) when is_atom(name) do
    set_schema(__CALLER__, name, [], block)
  end

  # Handle options with block (non-Ecto schema)
  defmacro schema(opts, do: block) when is_list(opts) do
    set_schema(__CALLER__, :default, opts, block)
  end

  # Handle Ecto schema modules with block (for schema merging) - only for module aliases
  defmacro schema({:__aliases__, _, _} = ecto_schema_module, do: block) do
    set_merged_schema(__CALLER__, :default, [], ecto_schema_module, block)
  end

  # Handle Ecto schema modules with options
  defmacro schema({:__aliases__, _, _} = ecto_schema_module, opts) when is_list(opts) do
    set_inferred_schema(__CALLER__, :default, opts, ecto_schema_module)
  end

  # schema/3 macros
  # Handle named schema with options and block
  defmacro schema(name, opts, do: block) when is_atom(name) and is_list(opts) do
    set_schema(__CALLER__, name, opts, block)
  end

  # Handle Ecto schema modules with options and block
  defmacro schema({:__aliases__, _, _} = ecto_schema_module, opts, do: block)
           when is_list(opts) do
    set_merged_schema(__CALLER__, :default, opts, ecto_schema_module, block)
  end

  @doc ~S"""
  Define validation rules that are applied to the data validated by the schema.

  ## Examples

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       email: maybe(:string),
      ...>       login: maybe(:string)
      ...>     }
      ...>   end
      ...>
      ...>   rule(:either_login_or_email, %{email: nil, login: nil}) do
      ...>     {:error, "email or login must be present"}
      ...>   end
      ...> end
      iex> UserContract.conform(%{email: "jane@doe.org", login: nil})
      {:ok, %{email: "jane@doe.org", login: nil}}
      iex> UserContract.conform(%{email: nil, login: "jane"})
      {:ok, %{email: nil, login: "jane"}}
      iex> {:error, errors} = UserContract.conform(%{email: nil, login: nil})
      iex> Enum.map(errors, &to_string/1)
      ["email or login must be present"]

  """
  defmacro rule(name, {data, _line, rest} = input, do: block) when is_atom(data) do
    pre =
      quote do
        Module.put_attribute(__MODULE__, :rules, unquote(name))

        def rule(unquote(name), unquote(input)), do: unquote(block)
      end

    post =
      if is_nil(rest) do
        []
      else
        quote do
          def rule(unquote(name), _), do: :ok
        end
      end

    quote do
      unquote(pre)
      unquote(post)
    end
  end

  def to_output({_, {:map, [head | tail]}}) do
    to_output(tail, to_output(head, %{}))
  end

  def to_output({_, {:list, results}}) do
    to_output(results)
  end

  def to_output({:list, results}) do
    to_output(results)
  end

  def to_output({:map, results}) do
    to_output(results, %{})
  end

  def to_output([head | tail]) do
    [to_output(head) | to_output(tail)]
  end

  def to_output({:ok, value}) do
    to_output(value)
  end

  def to_output(value) do
    value
  end

  def to_output(:ok, output) do
    output
  end

  def to_output([], output) do
    output
  end

  def to_output({:ok, {path, result}}, output) do
    put_in(output, Enum.map(path, &Access.key(&1, %{})), to_output(result))
  end

  def to_output({:error, _}, output) do
    output
  end

  def to_output({:list, results}, output) do
    to_output(results, output)
  end

  def to_output([head | tail], output) do
    to_output(tail, to_output(head, output))
  end

  defp set_schema(_caller, name, opts, {ecto_schema_module, block}) do
    quote do
      mod = __MODULE__

      schemas = Module.get_attribute(mod, :schemas, %{})

      # Infer schema from Ecto module
      ecto_schema =
        Drops.Schema.infer_and_compile(unquote(ecto_schema_module), unquote(opts))

      # Infer schema from block
      block_schema = Drops.Schema.infer_and_compile(unquote(block), unquote(opts))

      # Merge the schemas by combining their keys
      merged_keys = ecto_schema.keys ++ block_schema.keys
      compiled_schema = %{ecto_schema | keys: merged_keys}

      Module.put_attribute(
        mod,
        :schemas,
        Map.put(
          schemas,
          unquote(name),
          compiled_schema
        )
      )
    end
  end

  defp set_schema(_caller, name, opts, block) do
    quote do
      mod = __MODULE__

      schemas = Module.get_attribute(mod, :schemas, %{})

      # Get default schema options from module attribute if present
      default_opts = Module.get_attribute(mod, :schema_opts, [])

      # Merge provided options with defaults (provided options take precedence)
      merged_opts = Keyword.merge(default_opts, unquote(opts))

      Module.put_attribute(
        mod,
        :schemas,
        Map.put(
          schemas,
          unquote(name),
          Drops.Type.Compiler.visit(unquote(block), merged_opts)
        )
      )

      # Store schema metadata for compile-time access
      schema_meta = Module.get_attribute(mod, :schema_meta, %{})
      new_meta = %{type: :block, ecto_schema: false}

      Module.put_attribute(
        mod,
        :schema_meta,
        Map.put(schema_meta, unquote(name), new_meta)
      )
    end
  end

  defp set_inferred_schema(_caller, name, opts, input) do
    quote do
      mod = __MODULE__

      schemas = Module.get_attribute(mod, :schemas, %{})

      # Get default schema options from module attribute if present
      default_opts = Module.get_attribute(mod, :schema_opts, [])

      # Merge provided options with defaults (provided options take precedence)
      merged_opts = Keyword.merge(default_opts, unquote(opts))

      # Use the new protocol-based schema inference
      compiled_schema = Drops.Schema.infer_and_compile(unquote(input), merged_opts)

      Module.put_attribute(
        mod,
        :schemas,
        Map.put(schemas, unquote(name), compiled_schema)
      )

      # Store schema metadata for compile-time access
      schema_meta = Module.get_attribute(mod, :schema_meta, %{})

      new_meta = %{
        type: :inferred,
        ecto_schema: true,
        source_module: unquote(input)
      }

      Module.put_attribute(
        mod,
        :schema_meta,
        Map.put(schema_meta, unquote(name), new_meta)
      )
    end
  end

  defp set_merged_schema(_caller, name, opts, ecto_schema_module, block) do
    quote do
      mod = __MODULE__

      schemas = Module.get_attribute(mod, :schemas, %{})

      # Get default schema options from module attribute if present
      default_opts = Module.get_attribute(mod, :schema_opts, [])

      # Merge provided options with defaults (provided options take precedence)
      merged_opts = Keyword.merge(default_opts, unquote(opts))

      # Infer schema from Ecto module
      inferred_schema_ast =
        Drops.Schema.Inference.infer_schema(unquote(ecto_schema_module), merged_opts)

      # Get the block schema AST
      block_schema_ast = unquote(block)

      # Merge the schemas - block schema takes precedence
      merged_schema_ast = Map.merge(inferred_schema_ast, block_schema_ast)

      # Compile the merged schema using the custom compiler for Ecto schemas
      # This preserves the source_schema meta information
      compiled_schema =
        Drops.Schema.Compiler.compile(
          unquote(ecto_schema_module),
          merged_schema_ast,
          merged_opts
        )

      Module.put_attribute(
        mod,
        :schemas,
        Map.put(schemas, unquote(name), compiled_schema)
      )

      # Store schema metadata for compile-time access
      schema_meta = Module.get_attribute(mod, :schema_meta, %{})

      new_meta = %{
        type: :merged,
        ecto_schema: true,
        source_module: unquote(ecto_schema_module)
      }

      Module.put_attribute(
        mod,
        :schema_meta,
        Map.put(schema_meta, unquote(name), new_meta)
      )
    end
  end
end
