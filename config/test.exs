use Mix.Config

config :calcinator, Calcinator.Resources.Ecto.Repo.Repo,
  adapter: Ecto.Adapters.Postgres,
  database: "calcinator_test",
  pool: Ecto.Adapters.SQL.Sandbox

config :calcinator,
  ecto_repos: [Calcinator.Resources.Ecto.Repo.Repo]

# Print only warnings and errors during test
config :logger,
       level: :warn

config :phoenix, :format_encoders,
  "json-api": Poison
