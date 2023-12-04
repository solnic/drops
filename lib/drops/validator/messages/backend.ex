defmodule Drops.Validator.Messages.Backend do
  @moduledoc ~S"""
  Messages Backends are used to generate error messages from error results.

  ## Examples

      iex> defmodule MyBackend do
      ...>   use Drops.Validator.Messages.Backend
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
      iex> UserContract.conform(%{name: "", email: 312})
      {:error,
        [
          %Drops.Validator.Messages.Error.Type{
            path: [:email],
            text: "312 received but it must be a string",
            meta: %{args: [:string, 312], predicate: :type?}
          },
          %Drops.Validator.Messages.Error.Type{
            path: [:name],
            text: "cannot be empty",
            meta: %{args: [""], predicate: :filled?}
          }
        ]
      }

  """
  @callback text(atom(), any()) :: String.t()
  @callback text(atom(), any(), any()) :: String.t()

  defmacro __using__(_opts) do
    quote do
      @behaviour Drops.Validator.Messages.Backend

      alias Drops.Validator.Messages.Error

      def errors(results) when is_tuple(results) do
        [error(results)]
      end

      def errors(results) when is_list(results) do
        Enum.map(results, &error/1)
      end

      defp error(text) when is_binary(text) do
        %Error.Rule{text: text}
      end

      defp error({path, text}) when is_list(path) and is_binary(text) do
        %Error.Rule{text: text, path: path}
      end

      defp error(%{path: path} = error), do: error
      defp error(%Error.Sum{} = error), do: error

      defp error({:error, {path, {input, [predicate: :has_key?, args: [value]] = meta}}}) do
        %Error.Key{
          path: path ++ [value],
          text: text(:has_key?, value),
          meta: %{
            predicate: :has_key?,
            args: [value]
          }
        }
      end

      defp error(
             {:error,
              {path, {input, [predicate: predicate, args: [value, _] = args] = meta}}}
           ) do
        %Error.Type{path: path, text: text(predicate, value, input), meta: meta}
      end

      defp error({:error, {path, {input, [predicate: predicate, args: _] = meta}}}) do
        %Error.Type{path: path, text: text(predicate, input), meta: meta}
      end

      defp error({:error, {path, {:list, results}}}) when is_list(results) do
        errors = Enum.map(results, &error/1) |> Enum.reject(&is_nil/1)
        if Enum.empty?(errors), do: nil, else: %Error.Set{errors: errors}
      end

      defp error(results) when is_list(results) do
        errors = Enum.map(results, &error/1) |> Enum.reject(&is_nil/1)
        if Enum.empty?(errors), do: nil, else: %Error.Set{errors: errors}
      end

      defp error({:error, results}) when is_list(results) do
        %Error.Set{errors: Enum.map(results, &error/1)}
      end

      defp error({:error, {path, {:or, {left, right}}}}) do
        %Error.Sum{
          left: error({:error, {path, left}}),
          right: error({:error, {path, right}})
        }
      end

      defp error({:cast, error}) do
        %Error.Caster{error: error(error)}
      end

      defp error({:ok, _}), do: nil
    end
  end
end
