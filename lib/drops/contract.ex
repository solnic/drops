defmodule Drops.Contract do
  @moduledoc """
  Drops.Contract can be used to extend your module with data validation capabilities.
  """
  @moduledoc since: "0.1.0"

  @doc ~S"""
  Validates the given `data` against the schema defined in the module.

  Returns `{:ok, validated_data}`.

  ## Examples

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       required(:name) => type(:string),
      ...>       required(:age) => type(:integer)
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{name: "Jane", age: 48})
      {:ok, %{name: "Jane", age: 48}}
      iex> {:error, errors} = UserContract.conform(%{name: "Jane", age: "not an integer"})
      iex> Enum.map(errors, &to_string/1)
      ["age must be an integer"]

  """
  @doc since: "0.1.0"
  @callback conform(data :: map()) :: {:ok, map()} | {:error, list()}
  @callback conform(data :: map(), keys :: list()) :: {:ok, map()} | {:error, list()}
  @callback conform(data :: map(), schema :: Types.Map) :: {:ok, map()} | {:error, list()}
  @callback conform(data :: map(), schema :: Types.Map, keyword()) ::
              {:ok, map()} | {:error, list()}

  defmacro __using__(opts) do
    quote do
      use Drops.Validator

      alias Drops.Types
      alias Drops.Contract.Messages

      import Drops.Contract
      import Drops.Contract.Runtime
      import Drops.Types.Map.DSL

      @behaviour Drops.Contract

      @message_backend unquote(opts[:message_backend]) || Messages.DefaultBackend

      Module.register_attribute(__MODULE__, :rules, accumulate: true)

      @before_compile Drops.Contract.Runtime

      def conform(data) do
        conform(data, schema())
      end

      def conform(data, %Types.Map{atomize: true} = schema) do
        conform(Types.Map.atomize(data, schema.keys), schema.keys)
      end

      def conform(data, %Types.Map{} = schema) do
        conform(data, schema.keys)
      end

      def conform(data, %Types.Sum{} = type) do
        case conform(data, type.left) do
          {:ok, value} ->
            {:ok, value}

          {:error, _} = left_errors ->
            case conform(data, type.right) do
              {:ok, value} ->
                {:ok, value}

              {:error, error} = right_errors ->
                {:error, @message_backend.errors({:or, {left_errors, right_errors}})}
            end
        end
      end

      def conform(data, keys) when is_list(keys) do
        results = validate(data, keys)
        output = to_output(results)
        schema_errors = Enum.reject(results, &is_ok/1)
        rule_errors = apply_rules(output)

        all_errors = schema_errors ++ rule_errors

        if length(all_errors) > 0 do
          {:error, @message_backend.errors(collapse_errors(all_errors))}
        else
          {:ok, output}
        end
      end

      def conform(data, %Types.Map{} = schema, path: root) do
        case conform(data, schema) do
          {:ok, value} ->
            {:ok, {root, value}}

          {:error, errors} ->
            {:error, nest_errors(errors, root)}
        end
      end

      def validate(data, keys) when is_list(keys) do
        Enum.map(keys, &validate(data, &1)) |> List.flatten()
      end

      def validate(value, %Types.Map{} = schema, path: path) do
        case validate(value, schema.constraints, path: path) do
          {:ok, {_, validated_value}} ->
            conform(validated_value, schema, path: path)

          error ->
            error
        end
      end

      defp apply_predicates(value, {:and, [left, %Types.Map{} = schema]}, path: path) do
        case apply_predicate(left, {:ok, {path, value}}) do
          {:ok, _} ->
            conform(value, schema, path: path)

          {:error, error} ->
            {:error, error}
        end
      end

      defp apply_rules(output) do
        Enum.map(rules(), fn name -> apply(__MODULE__, :rule, [name, output]) end)
        |> Enum.filter(fn
          :ok -> false
          _ -> true
        end)
      end

      defp to_output(results) do
        Enum.reduce(results, %{}, fn result, acc ->
          case result do
            {:ok, {path, value}} ->
              if is_list(value),
                do: put_in(acc, path, map_list_results(value)),
                else: put_in(acc, path, value)

            {:ok, value} ->
              value

            :ok ->
              acc

            {:error, _} ->
              acc
          end
        end)
      end

      defp map_list_results(members) do
        Enum.map(members, fn member ->
          case member do
            {:ok, {_, value}} ->
              if is_list(value), do: map_list_results(value), else: value

            {:ok, value} ->
              if is_list(value), do: map_list_results(value), else: value

            value ->
              value
          end
        end)
      end

      defp nest_errors(errors, root) when is_list(errors) do
        Enum.map(errors, fn
          %{__struct__: _error_type} = error ->
            Messages.Error.Conversions.nest(error, root)

          {:error, {path, name, args}} ->
            {:error, nest_errors({path, name, args}, root)}

          {:error, error_list} ->
            nest_errors(error_list, root)

          {:or, {left, right}} ->
            {:or, {nest_errors(left, root), nest_errors(right, root)}}
        end)
        |> List.flatten()
      end

      defp nest_errors({path, name, args}, root) when is_list(path) do
        {root ++ path, name, args}
      end

      defp nest_errors({:error, errors}, root) do
        {:error, nest_errors(errors, root)}
      end

      defp collapse_errors(errors) when is_list(errors) do
        Enum.map(errors, fn
          {:error, {path, name, args}} ->
            {:error, {path, name, args}}

          {:error, error_list} ->
            collapse_errors(error_list)

          {:or, {left_errors, right_errors}} ->
            {:or, {collapse_errors(left_errors), collapse_errors(right_errors)}}

          result ->
            result
        end)
        |> List.flatten()
      end

      defp collapse_errors({:error, errors}) do
        {:error, collapse_errors(errors)}
      end

      defp collapse_errors(errors), do: errors
    end
  end

  defmodule Runtime do
    @moduledoc false
    defmacro __before_compile__(_env) do
      quote do
        def schema, do: @schemas[:default]
        def schema(name), do: @schemas[name]

        def schemas, do: @schemas

        def rules, do: @rules
      end
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
      ...>       required(:name) => type(:string),
      ...>       required(:age) => type(:integer)
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{name: "John", age: 21})
      {:ok, %{name: "John", age: 21}}
  """
  @spec schema(do: Macro.t()) :: Macro.t()
  defmacro schema(do: block) do
    set_schema(__CALLER__, :default, [], block)
  end

  @doc ~S"""
  Define schemas for the contract.

  ## Nested atomized schema

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema(atomize: true) do
      ...>     %{
      ...>       required(:user) => %{
      ...>         required(:name) => type(:string, [:filled?]),
      ...>         required(:age) => type(:integer),
      ...>         required(:address) => %{
      ...>           required(:city) => type(:string, [:filled?]),
      ...>           required(:street) => type(:string, [:filled?]),
      ...>           required(:zipcode) => type(:string, [:filled?])
      ...>         }
      ...>       }
      ...>     }
      ...>   end
      ...> end
      iex> {:error, errors} = UserContract.conform(%{
      ...>  "user" => %{
      ...>    "name" => "John",
      ...>    "age" => 21,
      ...>    "address" => %{
      ...>      "city" => "New York",
      ...>      "street" => "",
      ...>      "zipcode" => "10001"
      ...>    }
      ...>  }
      ...> })
      iex> Enum.map(errors, &to_string/1)
      ["user.address.street must be filled"]
      iex> UserContract.conform(%{
      ...>  "user" => %{
      ...>    "name" => "John",
      ...>    "age" => 21,
      ...>    "address" => %{
      ...>      "city" => "New York",
      ...>      "street" => "Central Park",
      ...>      "zipcode" => "10001"
      ...>    }
      ...>  }
      ...> })
      {:ok,
       %{
         user: %{
           name: "John",
           address: %{city: "New York", street: "Central Park", zipcode: "10001"},
           age: 21
         }
       }}

  ## Reusing schemas

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema(:address) do
      ...>     %{
      ...>       required(:street) => string(:filled?),
      ...>       required(:city) => string(:filled?),
      ...>       required(:zip) => string(:filled?),
      ...>       required(:country) => string(:filled?)
      ...>     }
      ...>   end
      ...>
      ...>   schema do
      ...>     %{
      ...>       required(:name) => string(),
      ...>       required(:age) => integer(),
      ...>       required(:address) => @schemas.address
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{
      ...>   name: "John",
      ...>   age: 21,
      ...>   address: %{
      ...>     street: "Main St.",
      ...>     city: "New York",
      ...>     zip: "10001",
      ...>     country: "USA"
      ...>   }
      ...> })
      {:ok,
       %{
         name: "John",
         address: %{
           zip: "10001",
           street: "Main St.",
           city: "New York",
           country: "USA"
         },
         age: 21
       }}
      iex> {:error, errors} = UserContract.conform(%{
      ...>   name: "John",
      ...>   age: "21",
      ...>   address: %{
      ...>     street: "Main St.",
      ...>     city: "",
      ...>     zip: "10001",
      ...>     country: "USA"
      ...>   }
      ...> })
      iex> Enum.map(errors, &to_string/1)
      ["address.city must be filled", "age must be an integer"]
  """
  @spec schema(name :: atom()) :: Macro.t()
  defmacro schema(name, do: block) when is_atom(name) do
    set_schema(__CALLER__, name, [], block)
  end

  @spec schema(opts :: keyword()) :: Macro.t()
  defmacro schema(opts, do: block) do
    set_schema(__CALLER__, :default, opts, block)
  end

  @spec schema(name :: atom(), opts :: keyword()) :: Macro.t()
  defmacro schema(name, opts, do: block) when is_atom(name) do
    set_schema(__CALLER__, name, opts, block)
  end

  @doc ~S"""
  Define validation rules that are applied to the data validated by the schema.

  ## Examples

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       required(:email) => maybe(:string),
      ...>       required(:login) => maybe(:string)
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
    pre = quote do
      Module.put_attribute(__MODULE__, :rules, unquote(name))

      def rule(unquote(name), unquote(input)), do: unquote(block)
    end

    post = if is_nil(rest) do
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

  defp set_schema(_caller, name, opts, block) do
    quote do
      mod = __MODULE__

      schemas = Module.get_attribute(mod, :schemas, %{})

      Module.put_attribute(
        mod,
        :schemas,
        Map.put(
          schemas,
          unquote(name),
          Drops.Types.from_spec(unquote(block), unquote(opts))
        )
      )
    end
  end
end
