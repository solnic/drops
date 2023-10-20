defmodule Drops.MixProject do
  use Mix.Project

  @source_url "https://github.com/solnic/drops"
  @version "0.1.0"

  def project do
    [
      app: :drops,
      version: @version,
      elixir: "~> 1.15",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      licenses: "MIT",
      description: "Tools for working with data effectively",
      package: package(),
      docs: docs()
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
      licenses: ["LGPLv3"],
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
          Drops.Validator.Messages,
          Drops.Casters,
          Drops.Predicates,
          Drops.Validator
        ],
        Types: [
          Drops.Types,
          Drops.Types.Type,
          Drops.Types.List,
          Drops.Types.Map,
          Drops.Types.Map.Key,
          Drops.Types.Map.DSL,
          Drops.Types.Sum,
          Drops.Types.Cast
        ]
      ]
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
