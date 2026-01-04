defmodule Orchid.MixProject do
  use Mix.Project

  def project do
    [
      app: :orchid,
      version: "0.5.1",
      build_path: "_build",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      elixirc_paths: elixirc_paths(Mix.env()),
      deps: deps(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ],
      name: "Orchid",
      description:
        "A lightweight and extensible workflow orchestration engine, written in Elixir.",
      package: package(),
      source_url: "https://github.com/SynapticStrings/Orchid",
      docs: docs()
    ]
  end

  def application do
    []
  end

  defp package do
    [
      licenses: ["MIT"],
      links: %{"GitHub" => "https://github.com/SynapticStrings/Orchid"},
      files:
        ~w(lib assets) ++ ~w(mix.exs .formatter.exs .dialyzer_ignore.exs README.md CHANGELOG.md)
    ]
  end

  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_), do: ["lib"]

  defp deps do
    [
      {:telemetry, "~> 1.3"},
      {:dialyxir, "~> 1.0", only: :dev, runtime: false, optional: true},
      {:ex_doc, "~> 0.39", only: :dev, runtime: false, warn_if_outdated: true}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      assets: %{"assets" => "assets"}
    ]
  end
end
