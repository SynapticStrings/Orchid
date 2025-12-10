defmodule QyCore.MixProject do
  use Mix.Project

  def project do
    [
      app: :qy_core,
      version: "0.2.1",
      build_path: "_build",
      # config_path: "config/config.exs",
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

  # 想要获得更多信息可运行 `mix help compile.app` 。
  def application do
    [
      # extra_applications: [:logger, :telemetry],
    ]
  end

  defp deps do
    [
      # 实现分布式追踪，hook 的底层实现
      {:telemetry, "~> 1.3"},
      ## 开发用
      {:dialyxir, "~> 1.0", only: [:dev], runtime: false, optional: true}
    ]
  end
end
