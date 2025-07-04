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
  `before_step/3` and `after_step/3` functions. The pipeline order is determined dynamically
  based on the steps that are actually present in the UnitOfWork.

  ## Usage

      # Create a UnitOfWork for an module
      uow = UnitOfWork.new(MyOperation)

      # Process parameters through the pipeline
      case UnitOfWork.process(uow, params) do
        {:ok, result} -> # success
        {:error, error} -> # failure
      end

  """

  @type step :: atom()
  @type step_definition :: {module(), atom()}
  @type callback_type :: :before | :after
  @type callback_definition :: {module(), atom(), any()}
  @type t :: %__MODULE__{
          steps: %{step() => step_definition()},
          step_order: [step()],
          module: module(),
          callbacks: %{callback_type() => %{step() => [callback_definition()]}}
        }

  defstruct [
    :steps,
    :step_order,
    :module,
    callbacks: %{before: %{}, after: %{}}
  ]

  @doc """
  Creates a new UnitOfWork for the given module.

  The UnitOfWork will be initialized with default steps that delegate
  to the module itself.

  ## Parameters

  - `module` - The module to create a UnitOfWork for

  ## Returns

  Returns a new UnitOfWork struct.
  """
  @spec new(module(), list(atom())) :: t()
  def new(module, step_names)
      when is_atom(module) and is_list(step_names) do
    # Build steps map from the provided step names
    steps = build_steps_map(module, step_names)

    %__MODULE__{
      module: module,
      steps: steps,
      step_order: step_names
    }
  end

  @doc """
  Adds a new step to the UnitOfWork.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `step_name` - The name of the new step
  - `module` - The module that contains the step function
  - `function` - The function name to call for this step

  ## Returns

  Returns the modified UnitOfWork with updated step order.
  """
  def add_step(%__MODULE__{} = uow, step_name) do
    updated_steps = Map.put(uow.steps, step_name, {uow.module, step_name})
    updated_step_order = uow.step_order ++ [step_name]
    %{uow | steps: updated_steps, step_order: updated_step_order}
  end

  @doc """
  Adds a new step to be called after an existing step.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `existing_step` - The existing step name to insert after
  - `new_step` - The new step name to add

  ## Returns

  Returns the modified UnitOfWork with updated step order.

  ## Examples

      # Add :audit step after :execute step
      uow = after_step(uow, :execute, :audit)

  """
  @spec after_step(t(), step(), step()) :: t()
  def after_step(%__MODULE__{} = uow, existing_step, new_step)
      when is_atom(existing_step) and is_atom(new_step) do
    case Enum.find_index(uow.step_order, &(&1 == existing_step)) do
      nil ->
        raise "Existing step #{existing_step} not found in UnitOfWork"

      index ->
        # Insert new step after the existing step
        updated_step_order = List.insert_at(uow.step_order, index + 1, new_step)
        updated_steps = Map.put(uow.steps, new_step, {uow.module, new_step})
        %{uow | step_order: updated_step_order, steps: updated_steps}
    end
  end

  @doc """
  Adds a new step to be called before an existing step.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `existing_step` - The existing step name to insert before
  - `new_step` - The new step name to add

  ## Returns

  Returns the modified UnitOfWork with updated step order.

  ## Examples

      # Add :audit step before :execute step
      uow = before_step(uow, :execute, :audit)

  """
  @spec before_step(t(), step(), step()) :: t()
  def before_step(%__MODULE__{} = uow, existing_step, new_step)
      when is_atom(existing_step) and is_atom(new_step) do
    case Enum.find_index(uow.step_order, &(&1 == existing_step)) do
      nil ->
        raise "Existing step #{existing_step} not found in UnitOfWork"

      index ->
        # Insert new step before the existing step
        updated_step_order = List.insert_at(uow.step_order, index, new_step)
        updated_steps = Map.put(uow.steps, new_step, {uow.module, new_step})
        %{uow | step_order: updated_step_order, steps: updated_steps}
    end
  end

  @doc """
  Registers a before callback for a specific step.

  Before callbacks are executed before the step function is called.
  The callback function will receive: `module`, `step`, `context`, and `config`.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `step` - The step name to attach the callback to
  - `module` - The module containing the callback function
  - `function` - The function name to call for this callback
  - `config` - Optional configuration data passed to the callback

  ## Returns

  Returns the modified UnitOfWork.

  ## Example

      def my_before_callback(module, step, context, config) do
        # Callback logic here
        :ok
      end
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
  The callback function will receive: `module`, `step`, `context`, `result`, and `config`.

  ## Parameters

  - `uow` - The UnitOfWork to modify
  - `step` - The step name to attach the callback to
  - `module` - The module containing the callback function
  - `function` - The function name to call for this callback
  - `config` - Optional configuration data passed to the callback

  ## Returns

  Returns the modified UnitOfWork.

  ## Example

      def my_after_callback(module, step, context, result, config) do
        # Callback logic here
        :ok
      end
  """
  @spec register_after_callback(t(), step(), module(), atom(), any()) :: t()
  def register_after_callback(%__MODULE__{} = uow, step, module, function, config \\ nil) do
    callback = {module, function, config}
    after_callbacks = Map.get(uow.callbacks.after, step, [])
    updated_after = Map.put(uow.callbacks.after, step, [callback | after_callbacks])
    %{uow | callbacks: %{uow.callbacks | after: updated_after}}
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

  This function executes all steps in the pipeline.

  ## Parameters

  - `uow` - The UnitOfWork defining the pipeline
  - `context` - The context map containing params and other data

  ## Returns

  Returns `{:ok, result}` or `{:error, error}`.
  """
  @spec process(t(), map()) :: {:ok, any()} | {:error, any()}
  def process(%__MODULE__{} = uow, context) when is_map(context) do
    # Process through the pipeline using the stored step order
    process_steps(uow, uow.step_order, context)
  end

  # Private functions

  defp build_steps_map(module, step_names) do
    Enum.into(step_names, %{}, fn step_name ->
      {step_name, {module, step_name}}
    end)
  end

  defp process_steps(_uow, [], result) do
    {:ok, result}
  end

  defp process_steps(uow, [step | remaining_steps], current_context) do
    case call_step(uow, step, current_context) do
      {:ok, result} ->
        process_steps(uow, remaining_steps, result)

      {:error, error} ->
        {:error, error}
    end
  end

  defp call_step(uow, step, context) do
    before_callbacks = Map.get(uow.callbacks.before, step, [])
    after_callbacks = Map.get(uow.callbacks.after, step, [])

    execute_before_callbacks(uow, step, context, before_callbacks)

    {module, function} = Map.get(uow.steps, step)
    result = apply(module, function, [context])

    # Only execute after callbacks if the step succeeded
    case result do
      {:ok, _} ->
        execute_after_callbacks(uow, step, context, result, after_callbacks)

      {:error, _} ->
        :ok
    end

    result
  end

  defp execute_before_callbacks(_uow, _step, _context, []), do: :ok

  defp execute_before_callbacks(uow, step, context, [{module, function, config} | rest]) do
    apply(module, function, [uow.module, step, context, config])
    execute_before_callbacks(uow, step, context, rest)
  end

  defp execute_after_callbacks(_uow, _step, _context, _result, []), do: :ok

  defp execute_after_callbacks(uow, step, context, result, [
         {module, function, config} | rest
       ]) do
    apply(module, function, [uow.module, step, context, result, config])
    execute_after_callbacks(uow, step, context, result, rest)
  end
end
