defmodule Drops.Contract.Messages.Backend do
  @moduledoc ~S"""
  Messages Backends are used to generate error messages from error results.

  ## Examples

      iex> defmodule MyBackend do
      ...>   use Drops.Contract.Messages.Backend
      ...>
      ...>   def text(:type?, type, input) do
      ...>     "#{inspect(input)} received but it must be a #{type}"
      ...>   end
      ...>
      ...>   def text(:filled?, _input) do
      ...>     "cannot be empty"
      ...>   end
      ...> end
      iex> defmodule UserContract do
      ...>   use Drops.Contract, message_backend: MyBackend
      ...>
      ...>   schema do
      ...>     %{
      ...>       required(:name) => string(:filled?),
      ...>       required(:email) => string(:filled?)
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{name: "", email: 312}) |> UserContract.errors()
      [
        %Drops.Contract.Messages.Error{
          path: [:email],
          text: "312 received but it must be a string",
          meta: %{args: [:string, 312], predicate: :type?}
        },
        %Drops.Contract.Messages.Error{
          path: [:name],
          text: "cannot be empty",
          meta: %{args: [""], predicate: :filled?}
        }
      ]

  """
  @callback text(atom(), any()) :: String.t()
  @callback text(atom(), any(), any()) :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour Drops.Contract.Messages.Backend

      alias Drops.Contract.Messages.Error

      def errors(results) do
        Enum.map(results, &error/1)
      end

      defp error({:error, {[], :has_key?, [value]}}) do
        %Error{
          path: List.flatten([value]),
          text: text(:has_key?, value),
          meta: %{
            predicate: :has_key?,
            args: [value]
          }
        }
      end

      defp error({:error, {path, predicate, [value, input] = args}}) do
        %Error{
          path: path,
          text: text(predicate, value, input),
          meta: %{
            predicate: predicate,
            args: args
          }
        }
      end

      defp error({:error, {path, predicate, [input] = args}}) do
        %Error{
          path: path,
          text: text(predicate, input),
          meta: %{
            predicate: predicate,
            args: args
          }
        }
      end

      defp error({:or, {left, right}}) do
        %Error.Sum{left: error(left), right: error(right)}
      end
    end
  end
end
