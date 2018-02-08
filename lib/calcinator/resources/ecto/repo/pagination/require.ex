defmodule Calcinator.Resources.Ecto.Repo.Pagination.Require do
  @moduledoc """
  An error is returned when `query_options[:page]` is `nil`.  A page of resources with the pagination information is
  returned when `query_options[:page]` is not `nil`.  This is a stronger form of
  `Calcinator.Resources.Ecto.Repo.Pagination.Allow` because it forces the caller to declare what page it wants. Using
  `Calcinator.Resources.Ecto.Repo.Pagination.Require` (or a default and maximum size) is recommended when not paginating
  would have a detrimental performance impact.
  """

  alias Alembic.{Document, Error, Source}
  alias Calcinator.Resources.Ecto.Repo.Pagination.Allow

  @behaviour Calcinator.Resources.Ecto.Repo.Pagination

  # Functions

  @impl Calcinator.Resources.Ecto.Repo.Pagination
  def paginate(repo, query, query_options) do
    case Map.get(query_options, :page) do
      nil ->
        {:error,
         %Document{
           errors: [
             %Error{
               detail: "Pagination parameters were not passed, but they are required",
               source: %Source{pointer: "/"},
               status: "422",
               title: "Pagination required"
             }
           ]
         }}

      _ ->
        Allow.paginate(repo, query, query_options)
    end
  end
end
