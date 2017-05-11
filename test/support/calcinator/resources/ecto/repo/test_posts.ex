defmodule Calcinator.Resources.Ecto.Repo.TestPosts do
  @moduledoc """
  `Calcinator.Resources.Ecto.Repo.TestPost` resources
  """

  use Calcinator.Resources.Ecto.Repo

  alias Calcinator.Resources.{Ecto.Repo.Repo, TestPost}

  # Functions

  ## Calcinator.Resources.Ecto.Repo callbacks

  def ecto_schema_module, do: TestPost

  def repo, do: Repo
end
