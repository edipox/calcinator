defmodule Calcinator.Resources.Ecto.Repo.TestComments do
  use Calcinator.Resources.Ecto.Repo

  # Functions

  ## Calcinator.Resources.Ecto.Repo callbacks

  def ecto_schema_module(), do: Calcinator.Resources.TestComment

  def repo(), do: Calcinator.Resources.Ecto.Repo.Repo
end
