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
      ...>       name: string(:filled?),
      ...>       email: string(:filled?)
      ...>     }
      ...>   end
      ...> end
      iex> UserContract.conform(%{name: "", email: 312})
      {:error,
        [
          %Drops.Validator.Messages.Error.Type{
            path: [:email],
            text: "312 received but it must be a string",
            meta: [predicate: :type?, args: [:string, 312]]
          },
          %Drops.Validator.Messages.Error.Type{
            path: [:name],
            text: "cannot be empty",
            meta: [predicate: :filled?, args: [""]]
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
        results
        |> Enum.map(&error/1)
        |> List.flatten()
        |> Enum.sort_by(fn
          %{path: path} when is_list(path) -> path
          _ -> []
        end)
      end

      defp error(text) when is_binary(text) do
        %Error.Rule{text: text}
      end

      defp error({path, text}) when is_list(path) and is_binary(text) do
        %Error.Rule{text: text, path: path}
      end

      defp error(%{path: path} = error), do: error

      defp error(
             {:error,
              {path, [input: input, predicate: predicate, args: [value, _]] = meta}}
           )
           when is_list(path) do
        %Error.Type{
          path: path,
          text: text(predicate, value, input),
          meta: Keyword.drop(meta, [:input])
        }
      end

      defp error({:error, {path, [input: value, predicate: predicate, args: _] = meta}})
           when is_list(path) do
        %Error.Type{
          path: path,
          text: text(predicate, value),
          meta: Keyword.drop(meta, [:input])
        }
      end

      defp error({:error, {path, {:map, results}}}) do
        Enum.map(results, &error/1)
        |> List.flatten()
        |> Enum.reject(&is_nil/1)
        |> Enum.map(&nest(&1, path))
      end

      defp error({:error, {:map, results}}) when is_list(results) do
        errors =
          results
          |> Enum.map(&error/1)
          |> Enum.reject(&is_nil/1)
          |> Enum.sort_by(fn error -> error.path end)

        %Error.Set{errors: errors}
      end

      defp error({:error, {path, {:list, results}}}) when is_list(results) do
        errors = Enum.map(results, &error/1) |> Enum.reject(&is_nil/1)
        if Enum.empty?(errors), do: nil, else: %Error.Set{errors: errors}
      end

      defp error({:error, {:list, results}}) when is_list(results) do
        errors =
          Enum.with_index(results, fn
            {:error, _} = result, index -> nest(error(result), [index])
            {:ok, _}, _ -> nil
          end)
          |> Enum.reject(&is_nil/1)

        if Enum.empty?(errors), do: nil, else: %Error.Set{errors: errors}
      end

      defp error(results) when is_list(results) do
        errors = Enum.map(results, &error/1) |> Enum.reject(&is_nil/1)
        if Enum.empty?(errors), do: nil, else: %Error.Set{errors: errors}
      end

      defp error({:error, results}) when is_list(results) do
        %Error.Set{errors: Enum.map(results, &error/1)}
      end

      defp error({:error, text}) when is_atom(text) or is_binary(text) do
        %Error.Rule{text: text}
      end

      defp error({:error, {path, text}}) when is_atom(text) or is_binary(text) do
        %Error.Rule{path: path, text: text}
      end

      defp error({:error, {:or, {left, right, opts}}}) do
        if not is_nil(opts[:name]) and not is_nil(opts[:path]) do
          meta = Keyword.drop(opts, [:name, :path])

          %Error.Type{path: opts[:path], text: text(opts[:name], opts), meta: meta}
        else
          %Error.Union{left: error(left), right: error(right)}
        end
      end

      defp error({:error, {path, {:or, {left, right, opts}}}}) do
        nest(
          error(
            {:error,
             {:or,
              {left, right,
               Keyword.merge(opts, path: Keyword.get(opts, :path, []) ++ path)}}}
          ),
          path
        )
      end

      defp error({:error, {path, {:cast, error}}}) do
        %Error.Caster{error: error({:error, {path, error}})}
      end

      defp error(:ok), do: nil
      defp error({:ok, _}), do: nil

      defp nest(error, path) do
        Error.Conversions.nest(error, path)
      end
    end
  end
end
