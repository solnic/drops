defmodule Mix.Tasks.Drops.Examples do
  @moduledoc """
  Lists all available Drops examples.

  ## Usage

      mix drops.examples

  This task scans the examples directory and displays all available example files
  organized by category, along with descriptions extracted from their comments.

  ## Example Output

      Available Drops Examples:
      
      📁 Contract Examples (examples/contract/):
        • schema-01.exs - Basic schema validation
        • errors-01.exs - Error handling patterns
        • rule-01.exs - Custom validation rules
      
      📁 Ecto Examples (examples/ecto/):
        • save_user_operation.exs - SaveUser operation with Ecto schema
        • schema-inference-01.ex - Schema inference from Ecto schemas
      
      📁 README Examples (examples/readme/):
        • schemas-01.ex - Basic schema usage
        • types-01.exs - Working with types
      
      To run an example: mix drops.example <path>

  """

  use Mix.Task

  @shortdoc "Lists all available Drops examples"

  @impl Mix.Task
  def run(_args) do
    examples_dir = "examples"

    unless File.exists?(examples_dir) do
      Mix.shell().error("Examples directory not found: #{examples_dir}")
      System.halt(1)
    end

    Mix.shell().info("Available Drops Examples:\n")

    examples_dir
    |> scan_examples()
    |> group_by_category()
    |> display_examples()

    Mix.shell().info("\nTo run an example: mix drops.example <path>")
    Mix.shell().info("Example: mix drops.example examples/readme/schemas-01.ex")
  end

  defp scan_examples(dir) do
    dir
    |> File.ls!()
    |> Enum.flat_map(fn item ->
      path = Path.join(dir, item)

      cond do
        File.dir?(path) and item != "." and item != ".." ->
          scan_examples(path)

        File.regular?(path) and (String.ends_with?(item, ".ex") or String.ends_with?(item, ".exs")) ->
          [{path, extract_description(path)}]

        true ->
          []
      end
    end)
    |> Enum.sort()
  end

  defp extract_description(file_path) do
    case File.read(file_path) do
      {:ok, content} ->
        content
        |> String.split("\n")
        |> Enum.take(10)  # Only check first 10 lines
        |> Enum.find_value(fn line ->
          line = String.trim(line)

          cond do
            String.starts_with?(line, "# Example:") ->
              String.trim_leading(line, "# Example:")

            String.starts_with?(line, "# ") and String.contains?(line, "example") ->
              String.trim_leading(line, "# ")

            true ->
              nil
          end
        end)
        |> case do
          nil -> "Example file"
          desc -> String.trim(desc)
        end

      {:error, _} ->
        "Example file"
    end
  end

  defp group_by_category(examples) do
    examples
    |> Enum.group_by(fn {path, _desc} ->
      path
      |> Path.dirname()
      |> String.replace("examples/", "")
      |> String.replace("examples", "root")
    end)
    |> Enum.sort_by(fn {category, _} -> category end)
  end

  defp display_examples(grouped_examples) do
    Enum.each(grouped_examples, fn {category, examples} ->
      category_name = format_category_name(category)
      Mix.shell().info("📁 #{category_name}:")

      Enum.each(examples, fn {path, description} ->
        filename = Path.basename(path)
        Mix.shell().info("  • #{filename} - #{description}")
      end)

      Mix.shell().info("")
    end)
  end

  defp format_category_name("root"), do: "Root Examples (examples/)"

  defp format_category_name(category) do
    category
    |> String.split("/")
    |> Enum.map(&String.capitalize/1)
    |> Enum.join(" ")
    |> Kernel.<>(" Examples (examples/#{category}/)")
  end
end
