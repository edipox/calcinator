defmodule Calcinator.Resources.Ecto.Repo.TestTags do
  @moduledoc """
  `Calcinator.Resources.Ecto.Repo.TestTag` resources
  """

  use Calcinator.Resources.Ecto.Repo

  alias Calcinator.Resources.{Ecto.Repo.Repo, TestTag}

  # Functions

  ## Calcinator.Resources.Ecto.Repo callbacks

  def ecto_schema_module, do: TestTag

  def repo, do: Repo
end
