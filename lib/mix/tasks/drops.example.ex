defmodule Mix.Tasks.Drops.Example do
  @moduledoc """
  Runs Drops examples with proper environment setup.

  ## Usage

      mix drops.example examples/readme/schemas-01.ex
      mix drops.example examples/ecto/save_user_operation.exs
      mix drops.example examples/contract/schema-01.exs

  This task automatically:
  - Runs in dev environment with examples support
  - Ensures dependencies are available
  - Runs the example file

  ## Examples

  Run a basic schema example:

      mix drops.example examples/readme/schemas-01.ex

  Run an Ecto operation example:

      mix drops.example examples/ecto/save_user_operation.exs

  Run a contract validation example:

      mix drops.example examples/contract/schema-01.exs

  ## Available Examples

  You can list all available examples by running:

      mix drops.examples

  """

  use Mix.Task

  @shortdoc "Runs a Drops example with proper environment setup"

  @impl Mix.Task
  def run([]) do
    Mix.shell().info("""
    Usage: mix drops.example <example_file>

    Examples:
      mix drops.example examples/readme/schemas-01.ex
      mix drops.example examples/ecto/save_user_operation.exs
      mix drops.example examples/contract/schema-01.exs

    To see all available examples, run: mix drops.examples
    """)
  end

  def run([example_path | _rest]) do
    # Validate the example file exists
    unless File.exists?(example_path) do
      Mix.shell().error("Example file not found: #{example_path}")
      Mix.shell().info("To see all available examples, run: mix drops.examples")
      System.halt(1)
    end

    # Run the example
    Mix.shell().info("Running example: #{example_path}")
    Mix.shell().info(String.duplicate("=", 60))

    try do
      Code.eval_file(example_path)
    rescue
      error ->
        Mix.shell().error("Error running example: #{inspect(error)}")
        System.halt(1)
    end

    Mix.shell().info(String.duplicate("=", 60))
    Mix.shell().info("Example completed successfully!")
  end
end
