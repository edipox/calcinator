defmodule Calcinator.Mixfile do
  use Mix.Project

  def project do
    [
      app: :calcinator,
      build_embedded: Mix.env == :prod,
      deps: deps(),
      docs: [
        extras: ~w(README.md)
      ],
      elixir: "~> 1.3",
      preferred_cli_env: [
        "credo": :test,
        "dialyze": :test,
        "docs": :test
      ],
      source_url: "https://github.com/C-S-D/calcinator",
      start_permanent: Mix.env == :prod,
      version: "0.1.0"
    ]
  end

  # Configuration for the OTP application
  #
  # Type "mix help compile.app" for more information
  def application do
    [applications: ~w(alembic ja_serializer logger)a]
  end

  # Dependencies can be Hex packages:
  #
  #   {:mydep, "~> 0.3.0"}
  #
  # Or git/path repositories:
  #
  #   {:mydep, git: "https://github.com/elixir-lang/mydep.git", tag: "0.1.0"}
  #
  # Type "mix help deps" for more examples and options
  defp deps do
    [
      # JSONAPI document coding
      {:alembic, "~> 2.2"},
      # Static Analysis
      {:credo, "0.4.12", only: [:test]},
      # Type checking
      {:dialyze, "~> 0.2.1", only: :test},
      {:ex_doc, "~> 0.14.0", only: :test},
      {:ja_serializer, "~> 0.11.0"}
    ]
  end
end
