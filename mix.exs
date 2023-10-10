defmodule Drops.MixProject do
  use Mix.Project

  def project do
    [
      app: :drops,
      version: "0.0.0",
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      licenses: "MIT",
      description: "Tools for working with data effectively",
      package: package()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  defp package() do
    [
      name: "drops",
      files: ~w(lib .formatter.exs mix.exs README* LICENSE CHANGELOG.md),
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/solnic/drops"}
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21.0", only: :dev}
    ]
  end
end
