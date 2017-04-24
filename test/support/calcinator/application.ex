defmodule Calcinator.Application do
  use Application

  def start(_type, _args) do
    import Supervisor.Spec, only: [supervisor: 2]

    children = [
      supervisor(Calcinator.Resources.Ecto.Repo.Repo, [])
    ]
    opts = [strategy: :one_for_one, name: Calcinator.Supervisor]
    Supervisor.start_link(children, opts)
  end
end