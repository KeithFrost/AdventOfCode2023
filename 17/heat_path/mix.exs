defmodule HeatPath.MixProject do
  use Mix.Project

  def project do
    [
      app: :heat_path,
      version: "0.1.0",
      elixir: "~> 1.13",
      start_permanent: Mix.env() == :prod,
      deps: deps(),
      escript: escript()
    ]
  end

  # Run "mix help compile.app" to learn about applications.
  def application do
    [
      extra_applications: [:logger]
    ]
  end

  # Run "mix help deps" to learn about dependencies.
  defp deps do
    [
      {:heap, "~> 3.0"}
    ]
  end

  defp escript do
    [main_module: HeatPath.CLI]
  end
end
