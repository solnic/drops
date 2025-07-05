defmodule Drops.Operations do
  @moduledoc """
  Operations framework for building composable business logic.

  Operations provide a structured way to implement business logic with
  a consistent pipeline of steps. They support extensions for adding
  functionality like parameter validation, database operations, and more.

  ## Basic Usage

      defmodule CreateUser do
        use Drops.Operations.Command

        schema do
          %{
            required(:name) => string(:filled?),
            required(:email) => string(:email?)
          }
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            case MyApp.create_user(params) do
              {:ok, user} -> {:ok, user}
              {:error, reason} -> {:error, reason}
            end
          end
        end
      end

      # Usage
      {:ok, user} = CreateUser.call(%{params: %{name: "John", email: "john@example.com"}})

  ## Extensions

  Operations can be extended with additional functionality:

  - `Drops.Operations.Extensions.Command` - Basic command pattern with prepare/validate/execute steps
  - `Drops.Operations.Extensions.Params` - Parameter validation using Drops contracts
  - `Drops.Operations.Extensions.Ecto` - Database operations with Ecto integration

  ## Pipeline

  Operations execute through a pipeline of steps defined by enabled extensions:

  1. `conform` - Parameter validation (Params extension)
  2. `prepare` - Context preparation (Command extension)
  3. `changeset` - Changeset creation (Ecto extension)
  4. `validate` - Business logic validation (Command/Ecto extensions)
  5. `execute` - Main operation logic (Command extension)

  ## Composition

  Operations can be composed together:

      {:ok, user} = CreateUser.call(%{params: user_params})
      {:ok, profile} = CreateProfile.call({:ok, user}, %{params: profile_params})

  ## Configuration

  Operations can be configured with options:

      defmodule MyOperations do
        use Drops.Operations,
          type: :command,
          extensions: [MyCustomExtension],
          repo: MyApp.Repo
      end

      defmodule CreateUser do
        use MyOperations
        # inherits configuration from MyOperations
      end
  """

  @opts [type: :abstract]
  @spec __opts__() :: keyword()
  def __opts__, do: @opts

  alias Drops.Operations.UnitOfWork

  defmacro __using__(opts) do
    source_module = __MODULE__
    merged_opts = merge_opts(source_module.__opts__(), opts)

    merged_opts =
      Keyword.put(
        merged_opts,
        :extensions,
        Enum.map(merged_opts[:extensions], &Macro.expand(&1, __CALLER__))
      )

    define(merged_opts)
  end

  @spec define(keyword()) :: Macro.t()
  def define(opts) do
    {ordered_extensions, set_opts} =
      resolve_extension_dependencies(opts[:extensions], opts)

    use_extensions =
      Enum.map(ordered_extensions, &quote(do: use(unquote(&1), unquote(set_opts))))

    quote location: :keep do
      import Drops.Operations

      @opts unquote(set_opts)

      @unit_of_work Drops.Operations.UnitOfWork.new(__MODULE__, [])

      @extensions @opts[:extensions]
      def __extensions__, do: @extensions

      Module.register_attribute(__MODULE__, :enabled_extensions, accumulate: true)
      unquote_splicing(use_extensions)

      def __enabled_extensions__, do: @enabled_extensions

      def __opts__, do: @opts

      @before_compile Drops.Operations

      defmacro __using__(opts) do
        source_module = __MODULE__
        merged_opts = merge_opts(source_module.__opts__(), opts)

        merged_opts =
          Keyword.put(
            merged_opts,
            :extensions,
            Enum.map(merged_opts[:extensions], &Macro.expand(&1, __CALLER__))
          )

        merged_opts = Keyword.put(merged_opts, :source_module, source_module)

        define(merged_opts)
      end

      def call(context) do
        Drops.Operations.call(context, __unit_of_work__())
      end

      def call(result, context) do
        Drops.Operations.call(result, context, __unit_of_work__())
      end
    end
  end

  defmacro __before_compile__(env) do
    module = env.module

    opts = Module.get_attribute(module, :opts)
    enabled_extensions = Enum.reverse(Module.get_attribute(module, :enabled_extensions))
    custom_steps = Module.get_attribute(module, :steps, [])

    extension_steps = Enum.map(enabled_extensions, fn extension -> extension.steps() end)

    source_module_steps =
      case opts[:source_module] do
        nil ->
          []

        source_module ->
          if function_exported?(source_module, :steps, 0) do
            [source_module.steps()]
          else
            []
          end
      end

    Enum.each(enabled_extensions, fn extension ->
      uow = extension.unit_of_work(Module.get_attribute(module, :unit_of_work), opts)
      Module.put_attribute(module, :unit_of_work, uow)
    end)

    quote do
      unquote_splicing(extension_steps)
      unquote_splicing(source_module_steps)
      unquote(custom_steps)
      def __unit_of_work__, do: @unit_of_work
    end
  end

  defmacro steps(do: block) do
    quote do
      @steps unquote(Macro.escape(block))

      def steps, do: @steps
    end
  end

  @doc """
  Executes the operation with the given context.

  The context must be a map containing a `:params` key with the input parameters.
  The operation will process the context through its configured pipeline of steps
  and return either `{:ok, result}` or `{:error, reason}`.

  ## Parameters

  - `context` - A map containing `:params` and optionally other context data

  ## Returns

  - `{:ok, result}` - When the operation succeeds
  - `{:error, reason}` - When the operation fails at any step

  ## Examples

  Using `Drops.Operations.Command`:

      defmodule CreateUser do
        use Drops.Operations.Command

        schema do
          %{
            required(:name) => string(:filled?),
            required(:email) => string(:email?)
          }
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            case MyApp.Users.create(params) do
              {:ok, user} -> {:ok, user}
              {:error, changeset} -> {:error, changeset}
            end
          end
        end
      end

      # Success case
      {:ok, user} = CreateUser.call(%{params: %{name: "John Doe", email: "john@example.com"}})
      # => {:ok, %{id: 1, name: "John Doe", email: "john@example.com"}}

      # Validation error
      {:error, errors} = CreateUser.call(%{params: %{name: "", email: "invalid"}})
      # => {:error, ["name must be filled", "email must be a valid email"]}

  With additional context:

      context = %{
        params: %{name: "Jane Doe", email: "jane@example.com"},
        user_id: 123,
        request_id: "req-456"
      }
      {:ok, result} = CreateUser.call(context)

  """
  @spec call(map(), UnitOfWork.t()) :: {:ok, any()} | {:error, any()}
  def call(context, uow) do
    UnitOfWork.process(uow, context)
  end

  @doc """
  Executes the operation with the result from a previous operation.

  This function enables operation composition by accepting the result tuple from
  a previous operation. If the previous operation succeeded (`{:ok, result}`),
  the result is added to the context as `:execute_result` and the operation
  proceeds. If the previous operation failed (`{:error, reason}`), the error
  is passed through without executing this operation.

  ## Parameters

  - `previous_result` - The result tuple from a previous operation: `{:ok, result}` or `{:error, reason}`
  - `context` - A map containing `:params` and optionally other context data

  ## Returns

  - `{:ok, result}` - When both the previous operation and this operation succeed
  - `{:error, reason}` - When either the previous operation or this operation fails

  ## Examples

  Composing operations:

      defmodule CreateUser do
        use Drops.Operations.Command

        schema do
          %{required(:name) => string(:filled?)}
        end

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, %{id: 1, name: params.name}}
          end
        end
      end

      defmodule CreateProfile do
        use Drops.Operations.Command

        schema do
          %{required(:bio) => string(:filled?)}
        end

        steps do
          @impl true
          def execute(%{execute_result: user, params: params}) do
            profile = %{user_id: user.id, bio: params.bio}
            {:ok, profile}
          end
        end
      end

      # Successful composition
      result = CreateUser.call(%{params: %{name: "John Doe"}})
               |> CreateProfile.call(%{params: %{bio: "Software Developer"}})
      # => {:ok, %{user_id: 1, bio: "Software Developer"}}

      # Failed first operation - second operation is skipped
      result = CreateUser.call(%{params: %{name: ""}})
               |> CreateProfile.call(%{params: %{bio: "Software Developer"}})
      # => {:error, ["name must be filled"]}

      # Failed second operation
      result = CreateUser.call(%{params: %{name: "John Doe"}})
               |> CreateProfile.call(%{params: %{bio: ""}})
      # => {:error, ["bio must be filled"]}

  Manual composition:

      {:ok, user} = CreateUser.call(%{params: %{name: "John Doe"}})
      {:ok, profile} = CreateProfile.call({:ok, user}, %{params: %{bio: "Developer"}})

  """
  @spec call({:ok, map(), UnitOfWork.t()} | {:error, any()}, map()) ::
          {:ok, any()} | {:error, any()}
  def call({:ok, previous_result}, context, uow) do
    UnitOfWork.process(uow, Map.put(context, :execute_result, previous_result))
  end

  def call({:error, _error} = error_result, _context, _uow) do
    error_result
  end

  @spec merge_opts(nil | module() | keyword(), keyword()) :: keyword()
  def merge_opts(nil, new_opts), do: new_opts

  @spec merge_opts(module(), keyword()) :: keyword()
  def merge_opts(module, new_opts) when is_atom(module) and is_list(new_opts) do
    merge_opts(module.__opts__(), new_opts)
  end

  @spec merge_opts(keyword(), keyword()) :: keyword()
  def merge_opts(parent_opts, new_opts) when is_list(parent_opts) and is_list(new_opts) do
    extensions =
      Keyword.get(parent_opts, :extensions, []) ++ Keyword.get(new_opts, :extensions, [])

    Keyword.merge(parent_opts, new_opts) |> Keyword.put(:extensions, extensions)
  end

  @spec resolve_extension_dependencies([module()], keyword()) :: {[module()], keyword()}
  defp resolve_extension_dependencies(extensions, opts) do
    # Build dependency graph
    all_extensions = collect_all_extensions(extensions, [])
    ordered_extensions = topological_sort(all_extensions)

    # Collect and merge default options from all extensions
    extension_opts =
      Enum.reduce(ordered_extensions, [], fn extension, acc ->
        if function_exported?(extension, :default_opts, 1) do
          extension_defaults = extension.default_opts(opts)
          merge_opts(acc, extension_defaults)
        else
          acc
        end
      end)

    # Merge extension options with user-provided options
    merged_opts = merge_opts(extension_opts, opts)

    {ordered_extensions, merged_opts}
  end

  @spec get_extension_dependencies(module()) :: [module()]
  defp get_extension_dependencies(extension) when is_atom(extension) do
    # Get the @depends_on module attribute from the extension
    case extension.__info__(:attributes)[:depends_on] do
      dependencies when is_list(dependencies) -> dependencies
      _ -> []
    end
  end

  # Handle AST nodes (during compilation) - they don't have dependencies yet
  defp get_extension_dependencies(_extension), do: []

  @spec collect_all_extensions([module()], [module()]) :: [module()]
  defp collect_all_extensions([], acc), do: Enum.reverse(acc)

  defp collect_all_extensions([extension | rest], acc) do
    if extension in acc do
      collect_all_extensions(rest, acc)
    else
      dependencies = get_extension_dependencies(extension)
      acc_with_deps = collect_all_extensions(dependencies, [extension | acc])
      collect_all_extensions(rest, acc_with_deps)
    end
  end

  @spec topological_sort([module()]) :: [module()]
  defp topological_sort(extensions) do
    # Simple topological sort using Kahn's algorithm
    # Build adjacency list and in-degree count
    {graph, in_degree} = build_dependency_graph(extensions)

    # Find nodes with no incoming edges
    queue = Enum.filter(extensions, fn ext -> Map.get(in_degree, ext, 0) == 0 end)

    sort_extensions(queue, graph, in_degree, [])
  end

  @spec build_dependency_graph([module()]) ::
          {%{module() => [module()]}, %{module() => integer()}}
  defp build_dependency_graph(extensions) do
    graph = Map.new(extensions, fn ext -> {ext, []} end)
    in_degree = Map.new(extensions, fn ext -> {ext, 0} end)

    Enum.reduce(extensions, {graph, in_degree}, fn ext, {g, deg} ->
      dependencies = get_extension_dependencies(ext)

      Enum.reduce(dependencies, {g, deg}, fn dep, {graph_acc, degree_acc} ->
        # dep -> ext (dependency points to dependent)
        graph_acc = Map.update(graph_acc, dep, [ext], fn deps -> [ext | deps] end)
        degree_acc = Map.update(degree_acc, ext, 1, fn count -> count + 1 end)
        {graph_acc, degree_acc}
      end)
    end)
  end

  @spec sort_extensions([module()], %{module() => [module()]}, %{module() => integer()}, [
          module()
        ]) :: [module()]
  defp sort_extensions([], _graph, _in_degree, result), do: Enum.reverse(result)

  defp sort_extensions([current | queue], graph, in_degree, result) do
    # Add current to result
    new_result = [current | result]

    # For each dependent of current, decrease in-degree
    dependents = Map.get(graph, current, [])

    {new_queue, new_in_degree} =
      Enum.reduce(dependents, {queue, in_degree}, fn dependent, {q, deg} ->
        new_degree = Map.get(deg, dependent) - 1
        new_deg = Map.put(deg, dependent, new_degree)

        if new_degree == 0 do
          {[dependent | q], new_deg}
        else
          {q, new_deg}
        end
      end)

    sort_extensions(new_queue, graph, new_in_degree, new_result)
  end
end
