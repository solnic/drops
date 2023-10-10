defmodule Drops.Types.Map.DSL do
  @moduledoc """
  DSL functions for defining map key and value type specifications.

  Functions from this module are typically used via Drops.Contract.schema/1
  """

  @type type() :: {:type, {atom(), keyword()}}

  @doc ~S"""
  Returns a required key specification.

  ## Examples
      %{
        required(:email) => type(:string)
      }
  """
  @doc since: "0.1.0"
  @spec required(atom()) :: {:required, atom()}
  def required(name) do
    {:required, name}
  end

  @doc ~S"""
  Returns an optional key specification.

  ## Examples
      %{
        optional(:age) => type(:integer)
      }
  """
  @doc since: "0.1.0"
  @spec optional(atom()) :: {:optional, atom()}
  def optional(name) do
    {:optional, name}
  end

  @doc ~S"""
  Returns a type cast specification.
  """
  @doc since: "0.1.0"
  @spec cast(type(), Keyword.t()) :: {:cast, {type(), Keyword.t()}}
  def cast(type, cast_opts \\ []) do
    {:cast, {type, cast_opts}}
  end

  @doc ~S"""
  Returns a type specification.

  ## Examples

      # string
      type(:string)

      # either a nil or a string
      type([:nil, :string])
  """
  @doc since: "0.1.0"

  @spec type({atom(), []}) :: type()
  @spec type([list: atom()]) :: type()
  @spec type([list: []]) :: type()
  @spec type([atom()]) :: [type()]
  @spec type(atom()) :: type()

  def type([list: members]) when is_map(members) or is_tuple(members) do
    {:type, {:list, members}}
  end

  def type([list: [type | predicates]]) do
    {:type, {:list, type(type, predicates)}}
  end

  def type({type, predicates}) when is_atom(type) do
    type(type, predicates)
  end

  def type(types) when is_list(types) do
    Enum.map(types, &type/1)
  end

  def type(type) do
    {:type, {type, []}}
  end

  @doc ~S"""
  Returns a type specification with additional constraints.

  ## Examples

      # string with that must be filled
      type(:string, [:filled?]),

      # an integer that must be greater than 18
      type(:integer, [gt?: 18])

  """
  @doc since: "0.1.0"

  @spec type(atom(), []) :: type()
  @spec type({:cast, {atom(), []}}, type()) :: type()

  def type(type, predicates) when is_list(predicates) do
    {:type, {type, predicates}}
  end

  def type({:cast, {input_type, cast_opts}}, output_type) do
    {:cast, {type(input_type), type(output_type), cast_opts}}
  end

  @doc ~S"""
  Returns a list type specification.

  ## Examples

      # a list with a specified member type
      list(:string)

      # a list with a specified sum member type
      list([:string, :integer])

  """
  @doc since: "0.1.0"

  @spec list([atom()]) :: type()

  def list(members) when is_map(members) or is_tuple(members) do
    type(list: members)
  end

  @doc ~S"""
  Returns a list type specification with a constrained member type

  ## Examples

      # a list with a specified member type
      list(:string, [:filled?])

      list(:integer, [gt?: 18])

  """
  @doc since: "0.1.0"

  @spec list([atom()]) :: type()

  def list(type, predicates \\ []) when is_list(predicates) do
    type(list: [type | predicates])
  end

  @doc ~S"""
  Returns a maybe type specification.

  ## Examples

      # either a nil or a string
      maybe(:string)

  """
  @doc since: "0.1.0"

  @spec maybe(atom()) :: type()
  @spec maybe(map()) :: [type()]

  def maybe(schema) when is_map(schema) do
    [type(:nil), schema]
  end

  @doc ~S"""
  Returns a maybe type specification with additional constraints.

  ## Examples

      # either a nil or a non-empty string
      maybe(:string, [:filled?])

  """
  @doc since: "0.1.0"

  @spec maybe(atom(), []) :: type()

  def maybe(type, predicates \\ []) do
    type([:nil, {type, predicates}])
  end

  @doc ~S"""
  Returns a string type specification.

  ## Examples

      # a string with no constraints
      string()

  """
  @doc since: "0.1.0"

  @spec string() :: type()

  def string() do
    type(:string)
  end

  @doc ~S"""
  Returns a string type specification with additional constraints.

  ## Examples

      # a string with constraints
      string(:filled?)

      # a string with multiple constraints
      string([:filled?, max_length?: 255])

  """
  @doc since: "0.1.0"

  @spec string(atom()) :: type()
  @spec string([]) :: type()

  def string(predicate) when is_atom(predicate) do
    string([predicate])
  end

  def string(predicates) when is_list(predicates) do
    type(:string, predicates)
  end

  @doc ~S"""
  Returns a integer type specification.

  ## Examples

      # a integer with no constraints
      integer()

  """
  @doc since: "0.1.0"

  @spec integer() :: type()

  def integer() do
    type(:integer)
  end

  @doc ~S"""
  Returns a integer type specification with additional constraints.

  ## Examples

      # a integer with constraints
      integer(:even?)

      # a integer with multiple constraints
      integer([:even?, gt?: 100])

  """
  @doc since: "0.1.0"

  @spec integer(atom()) :: type()
  @spec integer([]) :: type()

  def integer(predicate) when is_atom(predicate) do
    integer([predicate])
  end

  def integer(predicates) when is_list(predicates) do
    type(:integer, predicates)
  end

  @doc ~S"""
  Returns a map type specification.

  ## Examples

      # a map with no constraints
      map()

  """
  @doc since: "0.1.0"

  @spec map() :: type()

  def map() do
    type(:map)
  end

  @doc ~S"""
  Returns a map type specification with additional constraints.

  ## Examples

      # a map with constraints
      map(min_size?: 2)

  """
  @doc since: "0.1.0"

  @spec map(atom()) :: type()
  @spec map([]) :: type()

  def map(predicate) when is_atom(predicate) do
    map([predicate])
  end

  def map(predicates) when is_list(predicates) do
    type(:map, predicates)
  end
end
