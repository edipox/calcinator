defmodule Calcinator.Resources.Ecto.Repo.Pagination.Ignore do
  @moduledoc """
  `query_options[:page]` is ignored: all resources are always returned.  There is no pagination information ever
  returned.  This replicates the old, bugged behavior from versions < 5.1.0.
  """

  import Calcinator.Resources.Ecto.Repo, only: [wrap_ownership_error: 3]

  @behaviour Calcinator.Resources.Ecto.Repo.Pagination

  @impl Calcinator.Resources.Ecto.Repo.Pagination
  def paginate(repo, query, _) do
    case wrap_ownership_error(repo, :all, [query]) do
      {:error, :ownership} ->
        {:error, :ownership}

      all ->
        {:ok, all, nil}
    end
  end
end
