defmodule Calcinator.RelationshipView do
  @moduledoc """
  Defines `"show_relationhip.json-api"` and `show_relationship.json"` `render/2` clauses that defer to
  `render_relationship/2` and `render_relationship_links/1` callbacks.
  """

  # Functions

  def render("show_relationship.json-api", options) do
    render("show_relationship.json", options)
  end

  def render("show_relationship.json", %{conn: conn, data: relationship, view: view}) do
    %Alembic.Document{
      jsonapi: %{
        version: "1.0"
      },
      data: view.render_relationship(relationship, conn),
      links: view.render_relationship_links(conn)
    }
  end
end
