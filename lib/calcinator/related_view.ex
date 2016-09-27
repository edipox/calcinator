defmodule Calcinator.RelatedView do
  @moduledoc """
  Defines `"get_related_resource.json-api"` and `"get_related_sorce.json"` `render/2` clauses that defer to
  `render_related_resource/2` callbacks.
  """

  # Functions

  def render("get_related_resource.json-api", options) do
    render("get_related_resource.json", options)
  end

  def render("get_related_resource.json", options) do
    %Alembic.Document{
      data: render_related_resource(options),
      jsonapi: %{
        version: "1.0"
      }
    }
  end

  ## Private Functions

  defp render_attributes(%{data: model, view: view}) do
    Enum.reduce view.__attributes, %{}, fn attribute, acc ->
      Map.put(acc, attribute, Map.fetch!(model, attribute))
    end
  end

  defp render_related_resource(%{data: nil}), do: nil
  defp render_related_resource(options = %{conn: conn, data: model, view: view}) do
    %Alembic.Resource{
      type: view.type,
      id: model |> view.id(conn) |> to_string,
      attributes: render_attributes(options),
      links: view.render_related_links(options)
    }
  end
end
