defmodule Drops.Operations.UnitOfWork do
  @moduledoc """
  UnitOfWork defines the processing pipeline for Operations.

  The UnitOfWork system provides a structured way to define and execute
  a series of processing steps in a specific order. Each step is defined
  as a tuple of `{module, function}` that will be called during processing.

  ## Default Pipeline

  The default pipeline consists of:

  - `:conform` - Validates input against the schema and transforms it
  - `:prepare` - Prepares the conformed parameters for validation
  - `:validate` - Validates the prepared parameters
  - `:execute` - Executes the operation with validated parameters

  ## Extension Pipeline

  Extensions can inject additional steps into the pipeline by using the
  `inject_step/4` function. The pipeline order is determined dynamically
  based on the steps that are actually present in the UnitOfWork.

  ## Usage

      # Create a UnitOfWork for an operation module
      uow = UnitOfWork.new(MyOperation)

      # Process parameters through the pipeline
      case UnitOfWork.process(uow, params) do
        {:ok, result} -> # success
        {:error, error} -> # failure
      end

  """

  @type step :: atom()
  @type step_definition :: {module(), atom()}
  @type callback_type :: :before | :after | :around
  @type callback_definition :: {module(), atom(), any()}
  @type t :: %__MODULE__{
          steps: %{step() => step_definition()},
          operation_module: module(),
          callbacks: %{callback_type() => %{step() => [callback_definition()]}}
        }

  defstruct [
    :steps,
    :operation_module,
    callbacks: %{before: %{}, after: %{}, around: %{}}
  ]

  @doc """
  Creates a new UnitOfWork for the given operation module.

  The UnitOfWork will be initialized with default steps that delegate
  to the operation module itself.

  ## Parameters

  - `operation_module` - The operation module to create a UnitOfWork for

  ## Returns

  Returns a new UnitOfWork struct.
  """
  @spec new(module()) :: t()
  def new(operation_module) do
    %__MODULE__{
      operation_module: operation_module,
      steps: %{
        conform: {operation_module, :conform},
        prepare: {operation_module, :prepare},
        validate: {operation_module, :validate},
        execute: {operation_module, :execute}
      }
    }
  end

  @doc """
  Injects a new step into the UnitOfWork.

  This allows extensions to add new processing steps to the pipeline.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `step` - The step name to inject
  - `module` - The module containing the step function
  - `function` - The function name to call for this step

  ## Returns

  Returns the modified UnitOfWork.
  """
  @spec inject_step(t(), step(), module(), atom()) :: t()
  def inject_step(%__MODULE__{} = uow, step, module, function) do
    %{uow | steps: Map.put(uow.steps, step, {module, function})}
  end

  @doc """
  Registers a before callback for a specific step.

  Before callbacks are executed before the step function is called.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `step` - The step name to attach the callback to
  - `module` - The module containing the callback function
  - `function` - The function name to call for this callback
  - `config` - Optional configuration data passed to the callback

  ## Returns

  Returns the modified UnitOfWork.
  """
  @spec register_before_callback(t(), step(), module(), atom(), any()) :: t()
  def register_before_callback(%__MODULE__{} = uow, step, module, function, config \\ nil) do
    callback = {module, function, config}
    before_callbacks = Map.get(uow.callbacks.before, step, [])
    updated_before = Map.put(uow.callbacks.before, step, [callback | before_callbacks])
    %{uow | callbacks: %{uow.callbacks | before: updated_before}}
  end

  @doc """
  Registers an after callback for a specific step.

  After callbacks are executed after the step function completes successfully.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `step` - The step name to attach the callback to
  - `module` - The module containing the callback function
  - `function` - The function name to call for this callback
  - `config` - Optional configuration data passed to the callback

  ## Returns

  Returns the modified UnitOfWork.
  """
  @spec register_after_callback(t(), step(), module(), atom(), any()) :: t()
  def register_after_callback(%__MODULE__{} = uow, step, module, function, config \\ nil) do
    callback = {module, function, config}
    after_callbacks = Map.get(uow.callbacks.after, step, [])
    updated_after = Map.put(uow.callbacks.after, step, [callback | after_callbacks])
    %{uow | callbacks: %{uow.callbacks | after: updated_after}}
  end

  @doc """
  Registers an around callback for a specific step.

  Around callbacks wrap the step function execution and can control
  whether the step is executed and modify its result.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `step` - The step name to attach the callback to
  - `module` - The module containing the callback function
  - `function` - The function name to call for this callback
  - `config` - Optional configuration data passed to the callback

  ## Returns

  Returns the modified UnitOfWork.
  """
  @spec register_around_callback(t(), step(), module(), atom(), any()) :: t()
  def register_around_callback(%__MODULE__{} = uow, step, module, function, config \\ nil) do
    callback = {module, function, config}
    around_callbacks = Map.get(uow.callbacks.around, step, [])
    updated_around = Map.put(uow.callbacks.around, step, [callback | around_callbacks])
    %{uow | callbacks: %{uow.callbacks | around: updated_around}}
  end

  @doc """
  Overrides a specific step in the UnitOfWork.

  This allows extensions to replace default implementations with their own.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `step` - The step to override (:conform, :prepare, :validate, or :execute)
  - `module` - The module that contains the override function
  - `function` - The function name to call

  ## Returns

  Returns the updated UnitOfWork.
  """
  @spec override_step(t(), step(), module(), atom()) :: t()
  def override_step(%__MODULE__{} = uow, step, module, function) do
    put_in(uow.steps[step], {module, function})
  end

  @doc """
  Processes parameters through the UnitOfWork pipeline.

  This function executes the conform, prepare, and validate steps in order,
  but does NOT execute the :execute step. The execute step is handled
  separately by the Operations module.

  ## Parameters

  - `uow` - The UnitOfWork defining the pipeline
  - `context` - The context map containing params and other data

  ## Returns

  Returns `{:ok, %{original: original_params, prepared: prepared_params, validated: validated_params}}`
  on success or `{:error, error}` on failure.
  """
  @spec process(t(), map()) ::
          {:ok, %{original: any(), prepared: any(), validated: any()}} | {:error, any()}
  def process(%__MODULE__{} = uow, context) when is_map(context) do
    # Get the pipeline steps in order, excluding :execute
    pipeline = get_pipeline_steps(uow)

    # Extract params from context for backward compatibility
    params = Map.get(context, :params)

    # Process through the pipeline, keeping track of original context and prepared params
    process_pipeline(uow, pipeline, context, params, nil)
  end

  # Private functions

  defp get_pipeline_steps(uow) do
    schema = uow.operation_module.schema()

    # Define the base pipeline order - extensions can inject additional steps
    base_pipeline = [:conform, :prepare, :validate]

    # Get all available steps from the UoW
    available_step_names = Map.keys(uow.steps)

    # Start with base pipeline and add any additional steps that aren't in the base
    additional_steps = available_step_names -- (base_pipeline ++ [:execute])

    # Create the full pipeline by inserting additional steps in a logical order
    full_pipeline = insert_additional_steps(base_pipeline, additional_steps)

    # Filter to only include steps that are actually defined in the UoW
    available_steps =
      full_pipeline
      |> Enum.filter(fn step -> Map.has_key?(uow.steps, step) end)

    # Skip conform step if schema has no keys
    if length(schema.keys) == 0 do
      Enum.reject(available_steps, &(&1 == :conform))
    else
      available_steps
    end
  end

  # Insert additional steps in logical positions within the pipeline
  defp insert_additional_steps(base_pipeline, additional_steps) do
    # For now, insert additional steps after :prepare and before :validate
    # Extensions can override this behavior by providing their own pipeline logic
    case base_pipeline do
      [:conform, :prepare, :validate] ->
        [:conform, :prepare] ++ additional_steps ++ [:validate]

      other ->
        other ++ additional_steps
    end
  end

  defp process_pipeline(_uow, [], result, original_params, prepared_params) do
    {:ok, %{original: original_params, prepared: prepared_params, validated: result}}
  end

  defp process_pipeline(
         uow,
         [step | remaining_steps],
         current_context,
         original_params,
         prepared_params
       ) do
    case call_step(uow, step, current_context, original_params) do
      {:ok, result} ->
        # For conform step, result is params, so update context
        # For other steps, result should be the updated context
        updated_context =
          case step do
            :conform ->
              # conform returns params, so update the context
              Map.put(current_context, :params, result)

            _other ->
              # Other steps should return updated context
              if is_map(result) do
                result
              else
                # If step returns non-map, treat as params update
                Map.put(current_context, :params, result)
              end
          end

        # Store prepared context after the :prepare step
        new_prepared_params =
          if step == :prepare do
            Map.get(updated_context, :params)
          else
            prepared_params
          end

        process_pipeline(
          uow,
          remaining_steps,
          updated_context,
          original_params,
          new_prepared_params
        )

      {:error, error} ->
        {:error, error}
    end
  end

  defp call_step(uow, step, context, _original_params) do
    # Execute around callbacks if any exist
    around_callbacks = Map.get(uow.callbacks.around, step, [])

    if around_callbacks != [] do
      # Execute around callbacks (they control the step execution)
      execute_around_callbacks(uow, step, context, around_callbacks)
    else
      # No around callbacks, execute step with before/after callbacks
      execute_step_with_callbacks(uow, step, context)
    end
  rescue
    error ->
      {:error, error}
  end

  defp execute_step_with_callbacks(uow, step, context) do
    # Execute before callbacks
    before_callbacks = Map.get(uow.callbacks.before, step, [])
    execute_before_callbacks(uow, step, context, before_callbacks)

    # Execute the actual step
    result = execute_step_function(uow, step, context)

    case result do
      {:ok, step_result} ->
        # Execute after callbacks on success
        after_callbacks = Map.get(uow.callbacks.after, step, [])
        execute_after_callbacks(uow, step, context, step_result, after_callbacks)
        result

      {:error, _} = error ->
        error
    end
  end

  defp execute_step_function(uow, step, context) do
    {module, function} = uow.steps[step]

    case step do
      :conform ->
        # conform still works with params only
        params = Map.get(context, :params)
        apply(module, function, [params])

      _other_step ->
        # All other steps now work with context
        result =
          cond do
            module == uow.operation_module ->
              # For operation module functions, pass context
              apply(module, function, [context])

            true ->
              # For extension functions, pass operation module as first arg
              case function_arity(module, function) do
                2 ->
                  apply(module, function, [uow.operation_module, context])

                3 ->
                  # For 3-arity functions, we might need original context
                  apply(module, function, [uow.operation_module, context, context])

                _ ->
                  apply(module, function, [uow.operation_module, context])
              end
          end

        # Handle the case where the step function returns an error tuple
        case result do
          {:error, _} = error -> error
          other -> {:ok, other}
        end
    end
  end

  # Callback execution helpers

  defp execute_before_callbacks(_uow, _step, _context, []), do: :ok

  defp execute_before_callbacks(uow, step, context, [{module, function, config} | rest]) do
    try do
      apply(module, function, [step, context, config])
      execute_before_callbacks(uow, step, context, rest)
    rescue
      error ->
        # Log error but continue with other callbacks
        require Logger
        Logger.warning("Before callback failed: #{inspect(error)}")
        execute_before_callbacks(uow, step, context, rest)
    end
  end

  defp execute_after_callbacks(_uow, _step, _context, _result, []), do: :ok

  defp execute_after_callbacks(uow, step, context, result, [
         {module, function, config} | rest
       ]) do
    try do
      apply(module, function, [step, context, result, config])
      execute_after_callbacks(uow, step, context, result, rest)
    rescue
      error ->
        # Log error but continue with other callbacks
        require Logger
        Logger.warning("After callback failed: #{inspect(error)}")
        execute_after_callbacks(uow, step, context, result, rest)
    end
  end

  defp execute_around_callbacks(uow, step, context, [{module, function, config} | rest]) do
    try do
      # Around callbacks receive a function to call the next callback or the step
      next_fn = fn ->
        if rest == [] do
          execute_step_with_callbacks(uow, step, context)
        else
          execute_around_callbacks(uow, step, context, rest)
        end
      end

      apply(module, function, [step, context, next_fn, config])
    rescue
      error ->
        {:error, error}
    end
  end

  # Helper function to get function arity
  defp function_arity(module, function) do
    case :erlang.function_exported(module, function, 1) do
      true ->
        1

      false ->
        case :erlang.function_exported(module, function, 2) do
          true ->
            2

          false ->
            case :erlang.function_exported(module, function, 3) do
              true -> 3
              # Default fallback
              false -> 1
            end
        end
    end
  end
end
