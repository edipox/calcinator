defmodule Calcinator.Resources.Ecto.Repo.Pagination.Disallow do
  @moduledoc """
  All resources with `nil` pagination is returned when `query_options[:page]` is `nil`, but an error is returns if
  `query_optons[:page]` is not `nil`. This is an improvement over `Calcinator.Resources.Ecto.Repo.Pagination.Ignore`
  because it will tell callers that `query_options[:page]` will not be honored.
  """

  alias Alembic.{Document, Error, Source}
  alias Calcinator.Resources.Ecto.Repo.Pagination.Ignore

  @behaviour Calcinator.Resources.Ecto.Repo.Pagination

  @impl Calcinator.Resources.Ecto.Repo.Pagination
  def paginate(repo, query, query_options) do
    case Map.get(query_options, :page) do
      nil ->
        Ignore.paginate(repo, query, query_options)

      _ ->
        {:error,
         %Document{
           errors: [
             %Error{
               detail: "Pagination parameters were passed, but they are not allowed",
               source: %Source{pointer: "/page"},
               status: "422",
               title: "Pagination disallowed"
             }
           ]
         }}
    end
  end
end
