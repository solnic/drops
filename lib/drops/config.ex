defmodule Drops.Config do
  @moduledoc """
  Configuration management for Drops.

  This module provides a centralized configuration system for Drops, handling
  validation, persistence, and runtime access to configuration options.

  ## Configuration

  Drops can be configured through the application environment, under the `:drops` application.
  For example, you can do this in `config/config.exs`:

      # config/config.exs
      config :drops,
        # Configuration options here

  > #### Updating Configuration at Runtime {: .tip}
  >
  > If you *must* update configuration at runtime, use `put_config/2`. This
  > function is not efficient (since it updates terms in `:persistent_term`),
  > but it works in a pinch. For example, it's useful if you're changing
  > configuration during tests.

  ## Configuration Options

  ### `:registered_types`

  A list of type modules to register automatically when the Drops application starts.
  These modules should implement the Drops.Type behaviour.

  **Type:** list of `t:module/0`
  **Default:** `[]`



  ## Examples

      # Basic configuration
      config :drops,
        registered_types: [MyApp.CustomType]

      # Runtime configuration update (not recommended for production)
      Drops.Config.put_config(:registered_types, [MyApp.CustomType, MyApp.AnotherType])
  """

  @typedoc """
  A list of type modules to register automatically on application start.
  """
  @type registered_types :: [module()]

  # Configuration schema definition
  @config_schema [
    registered_types: [
      type: {:list, :atom},
      default: [],
      type_doc: "list of `t:module/0`",
      doc: """
      A list of type modules to register automatically when the Drops application starts.
      These modules should implement the Drops.Type behaviour.

      ## Example

          config :drops,
            registered_types: [MyApp.Types.CustomString, MyApp.Types.Email]
      """
    ]
  ]

  @opts_schema NimbleOptions.new!(@config_schema)
  @valid_keys Keyword.keys(@config_schema)

  @doc """
  Validates the current application configuration.

  This function reads the configuration from the `:drops` application environment
  and validates it according to the defined schema.

  ## Returns

  Returns the validated configuration as a keyword list.

  ## Raises

  Raises `ArgumentError` if the configuration is invalid.
  """
  @spec validate!() :: keyword()
  def validate! do
    :drops
    |> Application.get_all_env()
    |> validate!()
  end

  @doc """
  Validates the given configuration.

  ## Parameters

  - `config` - The configuration to validate as a keyword list

  ## Returns

  Returns the validated configuration as a keyword list.

  ## Raises

  Raises `ArgumentError` if the configuration is invalid.
  """
  @spec validate!(keyword()) :: keyword()
  def validate!(config) when is_list(config) do
    config_opts = Keyword.take(config, @valid_keys)

    case NimbleOptions.validate(config_opts, @opts_schema) do
      {:ok, opts} ->
        opts

      {:error, error} ->
        raise ArgumentError, """
        invalid configuration for the :drops application, so we cannot start or update
        its configuration. The error was:

            #{Exception.message(error)}

        See the documentation for the Drops.Config module for more information on configuration.
        """
    end
  end

  @doc """
  Persists the given configuration to `:persistent_term`.

  This function stores each configuration key-value pair in `:persistent_term`
  for efficient runtime access.

  ## Parameters

  - `config` - The validated configuration to persist as a keyword list

  ## Returns

  Returns `:ok`.
  """
  @spec persist(keyword()) :: :ok
  def persist(config) when is_list(config) do
    Enum.each(config, fn {key, value} ->
      :persistent_term.put({:drops_config, key}, value)
    end)
  end

  @doc """
  Returns the documentation for all configuration options.

  This function generates documentation for all available configuration options
  using the NimbleOptions schema.

  ## Returns

  Returns a string containing the formatted documentation.
  """
  @spec docs() :: String.t()
  def docs do
    NimbleOptions.docs(@opts_schema)
  end

  @doc """
  Gets the list of registered types.

  ## Returns

  Returns a list of type modules that have been registered.
  """
  @spec registered_types() :: [module()]
  def registered_types, do: fetch!(:registered_types)

  @doc """
  Updates the value of `key` in the configuration *at runtime*.

  Once the `:drops` application starts, it validates and caches the value of the
  configuration options you start it with. Because of this, updating configuration
  at runtime requires this function as opposed to just changing the application
  environment.

  > #### This Function Is Slow {: .warning}
  >
  > This function updates terms in [`:persistent_term`](`:persistent_term`), which is what
  > this library uses to cache configuration. Updating terms in `:persistent_term` is slow
  > and can trigger full GC sweeps. We recommend only using this function in rare cases,
  > or during tests.

  ## Parameters

  - `key` - The configuration key to update
  - `value` - The new value for the configuration key

  ## Returns

  Returns `:ok`.

  ## Raises

  Raises `ArgumentError` if the key is not a valid configuration option or if the
  value is invalid for the given key.

  ## Examples

      # Update registered types at runtime (useful for testing)
      Drops.Config.put_config(:registered_types, [MyApp.CustomType])
  """
  @spec put_config(atom(), term()) :: :ok
  def put_config(key, value) when is_atom(key) do
    unless key in @valid_keys do
      raise ArgumentError, "unknown option #{inspect(key)}"
    end

    [{key, value}]
    |> validate!()
    |> persist()
  end

  ## Private functions

  @compile {:inline, fetch!: 1}
  defp fetch!(key) do
    :persistent_term.get({:drops_config, key})
  rescue
    ArgumentError ->
      raise """
      the Drops configuration seems to be not available (while trying to fetch \
      #{inspect(key)}). This is likely because the :drops application has not been started yet. \
      Make sure that you start the :drops application before using any of its functions.
      """
  end
end
