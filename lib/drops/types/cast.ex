defmodule Drops.Types.Cast do
  @moduledoc ~S"""
  Drops.Types.Cast is a struct that represents a cast type with input and output types.

  ## Examples

      iex> Drops.Type.Compiler.visit(
      ...>   {:cast, {{:type, {:integer, []}}, {:type, {:date_time, []}}, [:miliseconds]}},
      ...>   []
      ...> )
      %Drops.Types.Cast{
        input_type: %Drops.Types.Primitive{
          primitive: :integer,
          constraints: [predicate: {:type?, :integer}]
        },
        output_type: %Drops.Types.Primitive{
          primitive: :date_time,
          constraints: [predicate: {:type?, :date_time}]
        },
        opts: [:miliseconds]
      }

  """

  alias Drops.Type.Validator
  alias Drops.Casters

  use Drops.Type do
    deftype([:input_type, :output_type, opts: []])

    def new(input_type, output_type, opts) do
      struct(__MODULE__, input_type: input_type, output_type: output_type, opts: opts)
    end
  end

  defimpl Validator do
    def validate(
          %{input_type: input_type, output_type: output_type, opts: cast_opts},
          value
        ) do
      caster = cast_opts[:caster] || Casters

      case Validator.validate(input_type, value) do
        {:ok, result} ->
          casted_value =
            apply(
              caster,
              :cast,
              [input_type.primitive, output_type.primitive, result] ++ cast_opts
            )

          Validator.validate(output_type, casted_value)

        {:error, error} ->
          {:error, {:cast, error}}
      end
    end
  end
end
