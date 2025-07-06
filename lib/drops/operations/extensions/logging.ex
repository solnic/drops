defmodule Drops.Operations.Extensions.Logging do
  @moduledoc """
  Logging extension for Operations framework.

  This extension provides configurable logging for Operations by leveraging telemetry events
  and a custom log handler. It supports both debug mode (detailed logging with context) and
  info mode (basic success/error logging) with configurable step filtering.

  ## Features

  - Configurable logging levels (debug mode vs info mode)
  - Automatic operation-level logging (start/stop events) with step-level error logging
  - Configurable step-level instrumentation
  - Configurable log handler (console, file, or memory)
  - Metadata includes operation module for all events, step name for step-level events, and execution context
  - Built on top of the Telemetry extension
  - Smart metadata dumping for complex types via MetadataDumper protocol

  ## Configuration

  The logging handler can be configured via application environment:

      config :drops, :logger,
        handler: :file,
        file: "log/operations.log",
        level: :debug,
        format: "[$level] $message $metadata\\n",
        metadata: [
          :operation,      # Operation module name (always included)
          :step,           # Step name (for step-level events)
          :duration_us,    # Duration in microseconds (for stop/exception events)
          :system_time,    # System time (for start events)
          :context,        # Execution context (debug mode and error events)
          :kind,           # Error kind (for exception events)
          :reason,         # Error reason (for exception events)
          :error_type,     # Error type (for structured errors like Ecto.Changeset)
          :errors          # Formatted errors (for structured errors)
        ]

  ## Usage

  ### Enable Basic Logging

  Enable default logging with info level (no context included):

      defmodule CreateUser do
        use Drops.Operations.Command, logging: true

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  This will log operation start/stop events at info level for successful operations,
  operation failure events at warning level with basic metadata (no context), and
  step error events at error level only when they occur in the last step.

  ### Enable Debug Logging

  Enable debug logging with detailed context:

      defmodule CreateUser do
        use Drops.Operations.Command, debug: true

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  ### Step-Level Configuration

  Configure logging for specific steps:

      defmodule CreateUser do
        use Drops.Operations.Command, logging: [steps: [:validate, :execute]]

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  Configure logging for all steps:

      defmodule CreateUser do
        use Drops.Operations.Command, logging: [steps: :all]

        steps do
          @impl true
          def execute(%{params: params}) do
            {:ok, create_user(params)}
          end
        end
      end

  ### Error Logging Configuration

  Control when step errors are logged:

      # Log all step errors (default behavior)
      defmodule CreateUser do
        use Drops.Operations.Command, logging: [log_all_errors: true]
      end

      # Only log errors when operation fails (recommended)
      defmodule CreateUser do
        use Drops.Operations.Command, logging: [log_all_errors: false]
      end

  When `log_all_errors: false` (default), step errors are only logged when they
  occur in the last step of the operation pipeline. This reduces noise from step
  errors in intermediate steps that are part of normal control flow.

  ## Logging Behavior

  ### Debug Mode (debug: true)

  - Logs at debug level for successful operations/steps
  - Logs at error level for failed operations/steps
  - Includes full context in all log messages
  - Logs all steps by default

  ### Info Mode (logging: true or logging: [steps: ...])

  - Logs at info level for successful operations/steps
  - Logs at error level for step errors in the last step (when log_all_errors: false)
  - Logs at warning level for operation failures with basic metadata (reason, error_type, duration, kind)
  - No context included for successful operations
  - Context included for failed operations in debug mode only
  - Configurable step filtering
  - Configurable step error logging behavior via `log_all_errors` option (default: false)

  ## Implementation Details

  This extension works by:

  1. Enabling telemetry with operation-level instrumentation and step-level error instrumentation
  2. Attaching telemetry handlers that log events using the custom logging handler
  3. Automatically cleaning up handlers when the operation module is unloaded

  The extension uses the Telemetry extension internally and attaches handlers
  during module compilation. When `logging: true` is specified, operation boundaries
  are instrumented for start/stop events. Step-level error instrumentation is
  controlled by the `log_all_errors` setting (default: false).
  """
  use Drops.Operations.Extension

  require Logger

  @depends_on [Drops.Operations.Extensions.Telemetry]

  @impl true
  @spec enable?(keyword()) :: boolean()
  def enable?(opts) do
    # Enable if either logging or debug is configured
    case {Keyword.get(opts, :logging, false), Keyword.get(opts, :debug, false)} do
      {false, false} -> false
      # debug: true takes precedence
      {_, true} -> true
      {_, config} when is_list(config) -> true
      {true, _} -> true
      {config, _} when is_list(config) -> true
      _ -> false
    end
  end

  @impl true
  @spec default_opts(keyword()) :: keyword()
  def default_opts(opts) do
    debug_config = Keyword.get(opts, :debug, false)
    logging_config = Keyword.get(opts, :logging, false)

    cond do
      debug_config != false ->
        # Debug mode: enable telemetry with all steps instrumented
        case debug_config do
          true ->
            [telemetry: [steps: :all]]

          config when is_list(config) ->
            # Pass through custom identifier but ensure all steps are instrumented
            identifier = Keyword.get(config, :identifier, :drops)
            [telemetry: [identifier: identifier, steps: :all]]
        end

      logging_config != false ->
        # Logging mode: configure telemetry based on logging config
        case logging_config do
          true ->
            # Default logging: instrument operation boundaries + all step errors
            # Maintain backward compatibility by logging all step errors by default
            [telemetry: true, telemetry_step_errors: :all]

          config when is_list(config) ->
            # Custom logging configuration
            identifier = Keyword.get(config, :identifier, :drops)
            steps = Keyword.get(config, :steps, [])
            log_all_errors = Keyword.get(config, :log_all_errors, false)

            telemetry_config =
              case steps do
                :all ->
                  [telemetry: [identifier: identifier, steps: :all]]

                [] ->
                  [telemetry: [identifier: identifier]]

                step_list when is_list(step_list) ->
                  [telemetry: [identifier: identifier, steps: step_list]]
              end

            # Add step error instrumentation based on log_all_errors setting
            if log_all_errors do
              Keyword.put(telemetry_config, :telemetry_step_errors, :all)
            else
              telemetry_config
            end
        end

      true ->
        []
    end
  end

  @impl true
  @spec unit_of_work(Drops.Operations.UnitOfWork.t(), keyword()) ::
          Drops.Operations.UnitOfWork.t()
  def unit_of_work(uow, opts) do
    debug_config = Keyword.get(opts, :debug, false)
    logging_config = Keyword.get(opts, :logging, false)

    # Determine which config to use (debug takes precedence)
    config =
      if debug_config != false,
        do: {:debug, debug_config},
        else: {:logging, logging_config}

    case config do
      {_, false} ->
        uow

      {mode, config_value} ->
        # Extract log_all_errors setting for later use
        log_all_errors = extract_log_all_errors_setting(mode, config_value)

        # Store logging config in module attribute for later use in __before_compile__
        Module.put_attribute(uow.module, :drops_logging_config, {mode, config_value})

        # Add a before callback to the first step to ensure handlers are attached
        first_step = List.first(uow.step_order)

        if first_step do
          Drops.Operations.UnitOfWork.register_before_callback(
            uow,
            first_step,
            __MODULE__,
            :ensure_logging_handlers_attached,
            %{logging_config: {mode, config_value}, log_all_errors: log_all_errors}
          )
        else
          uow
        end
    end
  end

  @impl true
  @spec using() :: Macro.t()
  def using do
    quote do
      # Ensure handlers are cleaned up when module is unloaded
      @before_compile Drops.Operations.Extensions.Logging
    end
  end

  @impl true
  @spec helpers() :: Macro.t()
  def helpers do
    quote do
      # No additional helpers needed
    end
  end

  @impl true
  @spec steps() :: Macro.t()
  def steps do
    quote do
      # No additional steps needed
    end
  end

  defmacro __before_compile__(env) do
    # Get the logging configuration from the module attributes
    logging_config = Module.get_attribute(env.module, :drops_logging_config)

    if logging_config do
      quote do
        def __logging_handler_id__, do: "logging-#{__MODULE__}"

        # Clean up handlers when module is unloaded
        @before_compile :__detach_logging_handlers__

        def __detach_logging_handlers__ do
          try do
            :telemetry.detach(__logging_handler_id__())
          rescue
            _ -> :ok
          end
        end
      end
    else
      quote do
        # No logging configuration, no handlers to manage
      end
    end
  end

  # Private functions

  defp extract_log_all_errors_setting(mode, config_value) do
    case {mode, config_value} do
      {:debug, _} ->
        # Debug mode always logs all errors
        true

      {:logging, true} ->
        # Default logging mode: only log errors from last step (log_all_errors: false)
        false

      {:logging, config} when is_list(config) ->
        # Custom logging config: check log_all_errors setting
        Keyword.get(config, :log_all_errors, false)

      _ ->
        false
    end
  end

  defp get_log_all_errors_setting(logging_config) do
    case logging_config do
      {:debug, _} ->
        # Debug mode always logs all errors
        true

      {:logging, true} ->
        # Default logging mode: only log errors from last step (log_all_errors: false)
        false

      {:logging, config} when is_list(config) ->
        # Custom logging config: check log_all_errors setting
        Keyword.get(config, :log_all_errors, false)

      _ ->
        false
    end
  end

  defp should_log_step_error?(log_all_errors, metadata) do
    if log_all_errors do
      # Log all step errors when explicitly configured
      true
    else
      # Only log errors from the last step in the UnitOfWork step_order
      is_last_step_in_pipeline?(metadata.operation, metadata.step)
    end
  end

  defp is_last_step_in_pipeline?(operation_module, step) do
    try do
      # Get the UnitOfWork from the operation module
      uow = operation_module.__unit_of_work__()

      # Check if this step is the last step in the step_order
      last_step = List.last(uow.step_order)
      step == last_step
    rescue
      # If we can't determine the step order, default to logging the error
      _ -> true
    end
  end

  @doc false
  def ensure_logging_handlers_attached(operation_module, _step, _context, config) do
    logging_config = config.logging_config

    # Try to attach handlers if not already attached
    try do
      attach_logging_handlers(operation_module, logging_config)
    rescue
      _ -> :ok
    end

    :ok
  end

  @doc false
  def attach_logging_handlers(operation_module, logging_config) do
    identifier = get_identifier(logging_config)
    handler_id = "logging-#{operation_module}"

    # Define the events we want to listen to
    events = [
      [identifier, :operation, :start],
      [identifier, :operation, :stop],
      [identifier, :operation, :exception],
      [identifier, :operation, :step, :start],
      [identifier, :operation, :step, :stop],
      [identifier, :operation, :step, :exception]
    ]

    # Attach the handler
    :telemetry.attach_many(
      handler_id,
      events,
      &__MODULE__.handle_logging_event/4,
      %{operation_module: operation_module, logging_config: logging_config}
    )
  end

  defp get_identifier(logging_config) do
    case logging_config do
      {:debug, true} -> :drops
      {:debug, config} when is_list(config) -> Keyword.get(config, :identifier, :drops)
      {:logging, true} -> :drops
      {:logging, config} when is_list(config) -> Keyword.get(config, :identifier, :drops)
      true -> :drops
      config when is_list(config) -> Keyword.get(config, :identifier, :drops)
      _ -> :drops
    end
  end

  defp get_logging_config(logging_config) do
    case logging_config do
      {:debug, _} ->
        # Debug mode: debug level for success, error level for failures, always include context
        {:debug, true}

      {:logging, _} ->
        # Info mode: info level for success, error level for failures, no context for success
        {:info, false}

      _ ->
        # Fallback to debug mode
        {:debug, true}
    end
  end

  @doc false
  def handle_logging_event(
        [_identifier, :operation, :start],
        measurements,
        metadata,
        config
      ) do
    operation_name = format_operation_name(metadata.operation)
    {log_level, include_context} = get_logging_config(config.logging_config)

    log_metadata = [
      operation: operation_name,
      system_time: measurements.system_time
    ]

    log_metadata =
      if include_context do
        context = format_context_for_logging(metadata.context)
        Keyword.put(log_metadata, :context, context)
      else
        log_metadata
      end

    Logger.log(log_level, "#{operation_name} started", log_metadata)
  end

  def handle_logging_event(
        [_identifier, :operation, :stop],
        measurements,
        metadata,
        config
      ) do
    operation_name = format_operation_name(metadata.operation)
    duration_us = System.convert_time_unit(measurements.duration, :native, :microsecond)
    duration_display = format_duration(duration_us)
    {log_level, include_context} = get_logging_config(config.logging_config)

    log_metadata = [
      operation: operation_name,
      duration_us: duration_us
    ]

    log_metadata =
      if include_context do
        context = format_context_for_logging(metadata.context)
        Keyword.put(log_metadata, :context, context)
      else
        log_metadata
      end

    Logger.log(
      log_level,
      "#{operation_name} succeeded in #{duration_display}",
      log_metadata
    )
  end

  def handle_logging_event(
        [_identifier, :operation, :exception],
        measurements,
        metadata,
        config
      ) do
    operation_name = format_operation_name(metadata.operation)
    duration_us = System.convert_time_unit(measurements.duration, :native, :microsecond)
    duration_display = format_duration(duration_us)
    reason_info = format_reason(metadata.reason)
    {_log_level, include_context} = get_logging_config(config.logging_config)

    # Build log metadata based on debug mode
    log_metadata =
      if include_context do
        # Debug mode: include full context and all metadata
        context = format_context_for_logging(metadata.context)

        [
          operation: operation_name,
          context: context,
          duration_us: duration_us,
          kind: metadata.kind
        ] ++ reason_info
      else
        # Non-debug mode: include basic info but no context
        basic_reason_info = extract_basic_reason_info(reason_info)

        [
          operation: operation_name,
          duration_us: duration_us,
          kind: metadata.kind
        ] ++ basic_reason_info
      end

    # Use warning level for operation failures in non-debug mode, error level in debug mode
    if include_context do
      Logger.error(
        "#{operation_name} failed in #{duration_display}",
        log_metadata
      )
    else
      Logger.warning(
        "#{operation_name} failed in #{duration_display}",
        log_metadata
      )
    end
  end

  def handle_logging_event(
        [_identifier, :operation, :step, :start],
        measurements,
        metadata,
        config
      ) do
    operation_name = format_operation_name(metadata.operation)
    {log_level, include_context} = get_logging_config(config.logging_config)

    log_metadata = [
      operation: operation_name,
      step: metadata.step,
      system_time: measurements.system_time
    ]

    log_metadata =
      if include_context do
        context = format_context_for_logging(metadata.context)
        Keyword.put(log_metadata, :context, context)
      else
        log_metadata
      end

    Logger.log(log_level, "#{operation_name}.#{metadata.step} started", log_metadata)
  end

  def handle_logging_event(
        [_identifier, :operation, :step, :stop],
        measurements,
        metadata,
        config
      ) do
    operation_name = format_operation_name(metadata.operation)
    duration_us = System.convert_time_unit(measurements.duration, :native, :microsecond)
    duration_display = format_duration(duration_us)
    {log_level, include_context} = get_logging_config(config.logging_config)

    log_metadata = [
      operation: operation_name,
      step: metadata.step,
      duration_us: duration_us
    ]

    log_metadata =
      if include_context do
        context = format_context_for_logging(metadata.context)
        Keyword.put(log_metadata, :context, context)
      else
        log_metadata
      end

    Logger.log(
      log_level,
      "#{operation_name}.#{metadata.step} succeeded in #{duration_display}",
      log_metadata
    )
  end

  def handle_logging_event(
        [_identifier, :operation, :step, :exception],
        measurements,
        metadata,
        config
      ) do
    # Check if we should log this step error
    log_all_errors = get_log_all_errors_setting(config.logging_config)

    if should_log_step_error?(log_all_errors, metadata) do
      operation_name = format_operation_name(metadata.operation)
      duration_us = System.convert_time_unit(measurements.duration, :native, :microsecond)
      duration_display = format_duration(duration_us)
      reason_info = format_reason(metadata.reason)

      # Always include context for error cases and always use error level
      context = format_context_for_logging(metadata.context)

      log_metadata =
        [
          operation: operation_name,
          step: metadata.step,
          context: context,
          duration_us: duration_us,
          kind: metadata.kind
        ] ++ reason_info

      Logger.error(
        "#{operation_name}.#{metadata.step} failed in #{duration_display}",
        log_metadata
      )
    end
  end

  # Private helper functions

  defp format_operation_name(operation) when is_atom(operation) do
    operation
    |> to_string()
    |> String.replace_prefix("Elixir.", "")
  end

  defp format_operation_name(operation), do: to_string(operation)

  defp format_context_for_logging(context) do
    # Pass the raw context to the logger formatter
    # The formatter will handle pretty-printing using inspect with proper options
    context
  end

  defp format_metadata_value(value) do
    try do
      Drops.Logger.MetadataDumper.dump(value)
    rescue
      Protocol.UndefinedError ->
        # Fallback to inspect for types without MetadataDumper implementation
        inspect(value, limit: 50, printable_limit: 100)
    end
  end

  defp format_reason(reason) do
    cond do
      # Handle Ecto.Changeset errors specially
      is_struct(reason, Ecto.Changeset) and Code.ensure_loaded?(Ecto.Changeset) ->
        [
          reason: :validation,
          error_type: "Ecto.Changeset",
          errors: format_changeset_errors(reason.errors)
        ]

      # Handle other structs with errors field
      is_struct(reason) and Map.has_key?(reason, :errors) ->
        struct_name =
          reason.__struct__ |> to_string() |> String.replace_prefix("Elixir.", "")

        [
          reason: :error,
          error_type: struct_name,
          errors: format_metadata_value(reason.errors)
        ]

      # Handle regular values
      true ->
        [reason: format_metadata_value(reason)]
    end
  end

  defp format_changeset_errors(errors) when is_list(errors) do
    errors
    |> Enum.map(fn {field, {message, _opts}} ->
      "#{field}: #{message}"
    end)
    |> Enum.join(", ")
  end

  defp format_changeset_errors(errors), do: format_metadata_value(errors)

  defp extract_basic_reason_info(reason_info) do
    # Extract only reason and error_type from the full reason info
    reason_info
    |> Keyword.take([:reason, :error_type])
  end

  defp format_duration(duration_us) when duration_us < 1000, do: "#{duration_us}μs"

  defp format_duration(duration_us) when duration_us < 1_000_000,
    do: "#{Float.round(duration_us / 1000, 2)}ms"

  defp format_duration(duration_us), do: "#{Float.round(duration_us / 1_000_000, 2)}s"
end
