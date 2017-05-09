defmodule Calcinator.Resources.Ecto.Repo.TestComments do
  @moduledoc """
  `Calcinator.Resources.Ecto.Repo.TestComment` resources
  """

  use Calcinator.Resources.Ecto.Repo

  alias Calcinator.Resources.{Ecto.Repo.Repo, TestComment}

  # Functions

  ## Calcinator.Resources.Ecto.Repo callbacks

  def ecto_schema_module, do: TestComment

  def repo, do: Repo
end
