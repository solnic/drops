defmodule Drops.Type do
  @moduledoc ~S"""
  Type behaviour and definition macros.
  """
  @moduledoc since: "0.2.0"

  alias __MODULE__
  alias Drops.Type.Compiler
  alias Drops.Types.Map.Key

  @doc ~S"""
  Define a custom map type.

  ## Basic primitive type

      defmodule Email do
        use Drops.Type, string()
      end

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       email: Email
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{email: "jane@doe.org"})
      {:ok, %{email: "jane@doe.org"}}
      iex> {:error, errors} = UserContract.conform(%{email: 1})
      {:error,
       [
         %Drops.Validator.Messages.Error.Type{
           path: [:email],
           text: "must be a string",
           meta: [predicate: :type?, args: [:string, 1]]
         }
       ]}
      iex> Enum.map(errors, &to_string/1)
      ["email must be a string"]

  ## Constrained primitive type

      defmodule FilledEmail do
        use Drops.Type, string(:filled?)
      end

      iex> defmodule UserContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       email: FilledEmail
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{email: "jane@doe.org"})
      {:ok, %{email: "jane@doe.org"}}
      iex> {:error, errors} = UserContract.conform(%{email: ""})
      {:error,
       [
         %Drops.Validator.Messages.Error.Type{
           path: [:email],
           text: "must be filled",
           meta: [predicate: :filled?, args: [""]]
         }
       ]}
      iex> Enum.map(errors, &to_string/1)
      ["email must be filled"]

  ## Custom map

      defmodule User do
        use Drops.Type, %{
          name: string(),
          email: string()
        }
      end

      iex> defmodule AccountContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       user: User
      ...>     }
      ...>   end
      ...> end
      iex> AccountContract.conform(%{user: %{name: "Jane", email: "janedoe.org"}})
      {:ok, %{user: %{name: "Jane", email: "janedoe.org"}}}
      iex> {:error, errors} = AccountContract.conform(%{user: %{name: "Jane", email: 1}})
      {:error,
       [
         %Drops.Validator.Messages.Error.Type{
           path: [:user, :email],
           text: "must be a string",
           meta: [predicate: :type?, args: [:string, 1]]
         }
       ]}
      iex> Enum.map(errors, &to_string/1)
      ["user.email must be a string"]

  ## Custom union

      defmodule Price do
        use Drops.Type, union([:integer, :float], gt?: 0)
      end

      iex> defmodule ProductContract do
      ...>   use Drops.Contract
      ...>
      ...>   schema do
      ...>     %{
      ...>       unit_price: Price
      ...>     }
      ...>   end
      ...> end
      iex> ProductContract.conform(%{unit_price: 1})
      {:ok, %{unit_price: 1}}
      iex> {:ok, %{unit_price: 1}}
      {:ok, %{unit_price: 1}}
      iex> ProductContract.conform(%{unit_price: 1.5})
      {:ok, %{unit_price: 1.5}}
      iex> {:ok, %{unit_price: 1.5}}
      {:ok, %{unit_price: 1.5}}
      iex> {:error, errors} = ProductContract.conform(%{unit_price: -1})
      {:error,
       [
         %Drops.Validator.Messages.Error.Type{
           path: [:unit_price],
           text: "must be greater than 0",
           meta: [predicate: :gt?, args: [0, -1]]
         }
       ]}
      iex> Enum.map(errors, &to_string/1)
      ["unit_price must be greater than 0"]
  """
  @doc since: "0.2.0"

  defmacro __using__({:%{}, _, _} = spec) do
    quote do
      import Drops.Type
      import Drops.Type.DSL

      keys =
        Enum.map(unquote(spec), fn {{presence, name}, type_spec} ->
          %Key{path: [name], presence: presence, type: Compiler.visit(type_spec, [])}
        end)

      use Drops.Types.Map, keys: keys
    end
  end

  defmacro __using__({:union, _, _} = spec) do
    quote do
      use Drops.Types.Union, unquote(spec)
    end
  end

  defmacro __using__(do: block) do
    quote do
      import Drops.Type
      import Drops.Type.DSL

      unquote(block)
    end
  end

  defmacro __using__(spec) do
    quote do
      import Drops.Type
      import Drops.Type.DSL

      deftype(
        primitive: Type.infer_primitive(unquote(spec)),
        constraints: Type.infer_constraints(unquote(spec))
      )

      def new(attributes) when is_list(attributes) do
        struct(__MODULE__, attributes)
      end

      def new(spec) do
        new(
          primitive: infer_primitive(spec),
          constraints: infer_constraints(spec)
        )
      end

      def new(spec, constraints) when is_list(constraints) do
        new(
          primitive: infer_primitive(spec),
          constraints: infer_constraints({:type, {spec, constraints}})
        )
      end

      defoverridable new: 1

      defimpl Drops.Type.Validator, for: __MODULE__ do
        def validate(type, value) do
          Drops.Predicates.Helpers.apply_predicates(value, type.constraints)
        end
      end
    end
  end

  @doc false
  defmacro deftype(primitive) when is_atom(primitive) do
    quote do
      deftype(
        primitive: unquote(primitive),
        constraints: type(unquote(primitive))
      )
    end
  end

  defmacro deftype(attributes) when is_list(attributes) do
    quote do
      alias __MODULE__

      @type t :: %__MODULE__{}

      Module.register_attribute(__MODULE__, :type_spec, accumulate: false)
      Module.register_attribute(__MODULE__, :opts, accumulate: false)

      @opts []

      defstruct(unquote(attributes) ++ [opts: @opts])
    end
  end

  @doc false
  defmacro deftype(primitive, attributes) when is_atom(primitive) do
    all_attrs =
      [primitive: primitive, constraints: Type.infer_constraints(primitive)] ++ attributes

    quote do
      deftype(unquote(all_attrs))
    end
  end

  @doc false
  def infer_primitive([]), do: :any
  def infer_primitive(map) when is_map(map), do: :map
  def infer_primitive(name) when is_atom(name), do: name
  def infer_primitive({:type, {name, _}}), do: name
  def infer_primitive(_), do: nil

  @doc false
  def infer_constraints([]), do: []
  def infer_constraints(map) when is_map(map), do: []
  def infer_constraints(type) when is_atom(type), do: [predicate(:type?, [type])]

  def infer_constraints(predicates) when is_list(predicates) do
    Enum.map(predicates, &predicate/1)
  end

  def infer_constraints({:type, {type, predicates}}) when length(predicates) > 0 do
    {:and, [predicate(:type?, type) | Enum.map(predicates, &predicate/1)]}
  end

  def infer_constraints({:type, {type, []}}) do
    [predicate(:type?, type)]
  end

  @doc false
  def predicate({name, args}) do
    predicate(name, args)
  end

  def predicate(name) do
    predicate(name, [])
  end

  @doc false
  def predicate(name, args) when name in [:in?, :not_in?] and length(args) == 1 do
    {:predicate, {name, [args]}}
  end

  @doc false
  def predicate(name, args) do
    {:predicate, {name, args}}
  end
end
