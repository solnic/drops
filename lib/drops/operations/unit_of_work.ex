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
  @type t :: %__MODULE__{
          steps: %{step() => step_definition()},
          operation_module: module()
        }

  defstruct [:steps, :operation_module]

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
  - `params` - The initial parameters to process

  ## Returns

  Returns `{:ok, %{original: original_params, prepared: prepared_params, validated: validated_params}}`
  on success or `{:error, error}` on failure.
  """
  @spec process(t(), any()) ::
          {:ok, %{original: any(), prepared: any(), validated: any()}} | {:error, any()}
  def process(%__MODULE__{} = uow, params) do
    # Get the pipeline steps in order, excluding :execute
    pipeline = get_pipeline_steps(uow)

    # Process through the pipeline, keeping track of original params and prepared params
    process_pipeline(uow, pipeline, params, params, nil)
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
         params,
         original_params,
         prepared_params
       ) do
    case call_step(uow, step, params, original_params) do
      {:ok, result} ->
        # Store prepared params after the :prepare step
        new_prepared_params = if step == :prepare, do: result, else: prepared_params

        process_pipeline(
          uow,
          remaining_steps,
          result,
          original_params,
          new_prepared_params
        )

      {:error, error} ->
        {:error, error}
    end
  end

  defp call_step(uow, step, params, original_params) do
    {module, function} = uow.steps[step]

    case step do
      :conform ->
        # conform returns {:ok, result} or {:error, errors}
        apply(module, function, [params])

      _other_step ->
        # All other steps return the result directly
        # Check the function arity to determine how to call it
        result =
          cond do
            module == uow.operation_module ->
              # For operation module functions, check arity
              case function_arity(module, function) do
                1 -> apply(module, function, [params])
                2 -> apply(module, function, [original_params, params])
                _ -> apply(module, function, [params])
              end

            true ->
              # For extension functions, pass operation module as first arg
              case function_arity(module, function) do
                2 ->
                  apply(module, function, [uow.operation_module, params])

                3 ->
                  apply(module, function, [uow.operation_module, original_params, params])

                _ ->
                  apply(module, function, [uow.operation_module, params])
              end
          end

        # Handle the case where the step function returns an error tuple
        case result do
          {:error, _} = error -> error
          other -> {:ok, other}
        end
    end
  rescue
    error ->
      {:error, error}
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
