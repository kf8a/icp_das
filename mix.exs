defmodule IcpDas.MixProject do
  use Mix.Project

  def project do
    [
      app: :icp_das,
      version: "0.1.0",
      elixir: "~> 1.8",
      start_permanent: Mix.env() == :prod,
      deps: deps()
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
      {:circuits_uart, "~> 1.3"},
      {:ex_doc, "~> 0.22", only: :dev, runtime: false},
      {:toml, "~> 0.6.2"},
    ]
  end
end
