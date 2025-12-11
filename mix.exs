defmodule Orchid.MixProject do
  use Mix.Project

  def project do
    [
      app: :orchid,
      version: "0.3.0",
      build_path: "_build",
      deps_path: "deps",
      lockfile: "mix.lock",
      elixir: "~> 1.17",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      dialyzer: [
        ignore_warnings: ".dialyzer_ignore.exs",
        list_unused_filters: true
      ]
    ]
  end

  def application do
    [
      # extra_applications: [:logger, :telemetry],
    ]
  end

  defp deps do
    [
      {:telemetry, "~> 1.3"},
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false, optional: true}
    ]
  end
end
