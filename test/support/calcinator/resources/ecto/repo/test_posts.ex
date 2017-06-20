defmodule Calcinator.Resources.Ecto.Repo.TestPosts do
  @moduledoc """
  `Calcinator.Resources.Ecto.Repo.TestPost` resources
  """

  use Calcinator.Resources.Ecto.Repo

  alias Calcinator.Resources.{Ecto.Repo.Repo, TestPost}

  import Calcinator.Resources, only: [split_filter_value: 1, unknown_filter: 1]
  import Ecto.Query, only: [where: 3]

  # Functions

  ## Calcinator.Resources.Ecto.Repo callbacks

  def ecto_schema_module, do: TestPost

  def filter(query, "id", comma_separated_ids) do
    {:ok, where(query, [i], i.id in ^split_filter_value(comma_separated_ids))}
  end
  def filter(_, name, _), do: {:error, unknown_filter(name)}

  def repo, do: Repo
end
