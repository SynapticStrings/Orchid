defmodule Orchid.MixProject do
  use Mix.Project

  def project do
    [
      app: :orchid,
      version: "0.5.8",
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
      docs: docs(),
      test_coverage: [tool: ExCoveralls]
    ]
  end

  def cli do
    [preferred_envs: [coveralls: :test, "coveralls.github": :test, "coveralls.json": :test]]
  end

  def application do
    [extra_applications: [:logger]]
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
      {:dialyxir, "~> 1.0", only: [:dev, :test], runtime: false, optional: true},
      {:ex_doc, "~> 0.40", only: :dev, runtime: false, warn_if_outdated: true},
      {:excoveralls, "~> 0.18.5", only: [:dev, :test], runtime: false, optional: true}
    ]
  end

  defp docs do
    [
      main: "readme",
      extras: ["README.md", "CHANGELOG.md"],
      assets: %{"assets" => "assets"},
      groups_for_modules: groups_for_modules()
    ]
  end

  def groups_for_modules do
    [
      Data: [Orchid.Param, Orchid.Repo],
      "Dataflow Declaration": [
        Orchid.Step,
        Orchid.Recipe,
        Orchid.Step.NestedStep
      ],
      Orchestration: [
        Orchid.Scheduler,
        Orchid.Scheduler.Context,
        Orchid.Recipe.Graph
      ],
      "Dataflow-level Middleware": [
        Orchid.Pipeline,
        Orchid.Operon,
        Orchid.Operon.Request,
        Orchid.Operon.Response,
        Orchid.Operon.Execute
      ],
      "Dataflow-Level Executor": [
        Orchid.Executor,
        Orchid.Executor.Async,
        Orchid.Executor.Serial
      ],
      "Step-level Executor": [Orchid.Runner, Orchid.Runner.Context],
      "Step-level Middleware": [
        Orchid.Runner.Hook,
        Orchid.Runner.Hooks.Core,
        Orchid.Runner.Hooks.Telemetry
      ],
      "Context Pass-through": [Orchid.WorkflowCtx],
      Inspection: [Orchid.Step.ID]
    ]
  end
end
