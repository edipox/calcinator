use Mix.Config

config :calcinator,
       Calcinator.Resources.Ecto.Repo.Repo,
       adapter: Ecto.Adapters.Postgres,
       database: "calcinator_test",
       hostname: "localhost",
       loggers: [PryIn.EctoLogger, Ecto.LogEntry],
       password: "postgres",
       pool: Ecto.Adapters.SQL.Sandbox,
       username: "postgres"

config :calcinator,
       ecto_repos: [Calcinator.Resources.Ecto.Repo.Repo],
       instrumenters: [Calcinator.PryIn.Instrumenter]

# Print only warnings and errors during test
config :logger,
       level: :warn

config :phoenix, :format_encoders,
       "json-api": Poison

config :pryin,
       api: Calcinator.PryIn.Api.Test,
       env: :staging,
       otp_app: :calcinator
