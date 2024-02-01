defmodule Drops.MixProject do
  use Mix.Project

  @source_url "https://github.com/solnic/drops"
  @version "0.2.0"
  @license "LGPL-3.0-or-later"

  def project do
    [
      app: :drops,
      version: @version,
      elixir: "~> 1.14",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      licenses: [@license],
      description: ~S"""
      Tools for working with data effectively - data contracts using types, schemas, domain validation rules, type-safe casting, and more.
      """,
      links: %{"GitHub" => @source_url},
      package: package(),
      docs: docs(),
      source_url: @source_url,
      consolidate_protocols: Mix.env() == :prod,
      elixir_paths: elixir_paths(Mix.env())
    ]
  end

  def elixir_paths(:examples) do
    elixir_paths("dev") ++ ["examples"]
  end

  def elixir_paths(_) do
    ["lib"]
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
      licenses: [@license],
      links: %{"GitHub" => "https://github.com/solnic/drops"}
    ]
  end

  defp docs do
    [
      main: "readme",
      source_ref: "v#{@version}",
      extra_section: "GUIDES",
      source_url: @source_url,
      skip_undefined_reference_warnings_on: ["CHANGELOG.md"],
      extras: [
        "README.md",
        "CHANGELOG.md"
      ],
      groups_for_modules: [
        Validation: [
          Drops.Contract,
          Drops.Casters,
          Drops.Predicates,
          Drops.Validator.Messages.Backend
        ],
        Types: [
          Drops.Types,
          Drops.Types.Primitive,
          Drops.Types.List,
          Drops.Types.Map,
          Drops.Types.Map.Key,
          Drops.Type.DSL,
          Drops.Types.Union,
          Drops.Types.Cast
        ],
        "Type DSL": [
          Drops.Type,
          Drops.Type.DSL,
          Drops.Type.Validator
        ]
      ]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:ex_doc, ">= 0.0.0", only: :dev, runtime: false},
      {:credo, "~> 1.6", only: [:dev, :test], runtime: false},
      {:doctor, "~> 0.21.0", only: :dev},
      {:dialyxir, "~> 1.4", only: [:dev, :test], runtime: false}
    ]
  end
end
