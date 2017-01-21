defmodule Calcinator.Mixfile do
  use Mix.Project

  def project do
    [
      app: :calcinator,
      build_embedded: Mix.env == :prod,
      deps: deps(),
      description: description(),
      docs: docs(),
      elixir: "~> 1.3",
      elixirc_paths: elixirc_paths(Mix.env),
      package: package(),
      preferred_cli_env: [
        "credo": :test,
        "dialyze": :test,
        "docs": :test
      ],
      source_url: "https://github.com/C-S-D/calcinator",
      start_permanent: Mix.env == :prod,
      version: "1.6.0"
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
      {:alembic, ">= 3.1.1 and < 3.2.0"},
      # Static Analysis
      {:credo, "0.5.3", only: [:test]},
      # Type checking
      {:dialyze, "~> 0.2.1", only: :test},
      {:ex_doc, "~> 0.14.0", only: [:dev, :test]},
      {:ja_serializer, "~> 0.11.0"},
      # JUnit formatter, so that CircleCI can consume test output for CircleCI UI
      {:junit_formatter, "~> 1.0", only: :test},
      # Phoenix.Controller is used in Calcinator.Controller.Error
      {:phoenix, "~> 1.0", optional: true}
    ]
  end

  defp description do
    """
    Process JSONAPI requests in transport and backing store neutral way.
    """
  end

  defp docs do
    [
      extras: ~w(CHANGELOG.md CODE_OF_CONDUCT.md CONTRIBUTING.md LICENSE.md README.md)
    ]
  end

  # Specifies which paths to compile per environment.
  defp elixirc_paths(:test), do: ["lib", "test/support"]
  defp elixirc_paths(_),     do: ["lib"]

  defp extras do
    [
      "CODE_OF_CONDUCT.md",
      "CONTRIBUTING.md",
      "LICENSE.md",
      "README.md",
    ]
  end

  defp package do
    [
      files: ["lib", "mix.exs" | extras()],
      licenses: ["Apache 2.0"],
      links: %{
        "Docs" => "https://hexdocs.pm/calcinator",
        "Github" => "https://github.com/C-S-D/calcinator",
      },
      maintainers: ["Luke Imhoff"]
    ]
  end
end
