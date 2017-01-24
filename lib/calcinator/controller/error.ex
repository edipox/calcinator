if Code.ensure_loaded?(Phoenix.Controller) do
  defmodule Calcinator.Controller.Error do
    @moduledoc """
    Errors returned by `Calcinator.Controller`.  Public, so that other controllers not using `Calcinator.Controller` can
    have same format for errors.
    """

    alias Alembic.{Document, Error, Source}
    alias Calcinator.ChangesetView
    alias Plug.Conn

    import Conn, only: [halt: 1, put_resp_content_type: 2, put_status: 2]
    import Phoenix.Controller, only: [json: 2, render: 4]

    @doc """
    Retort returned a 500 JSONAPI error inside a 422 JSONRPC error.
    """
    @spec bad_gateway(Conn.t) :: Conn.t
    def bad_gateway(conn) do
      conn
      |> put_status(:bad_gateway)
      |> put_resp_content_type("application/vnd.api+json")
      |> json(
           %Document{
             errors: [
               %Error{
                 status: "502",
                 title: "Bad Gateway"
               }
             ]
           }
         )
    end

    @doc """
    The current resource or action is forbidden to the authenticated user
    """
    @spec forbidden(Conn.t) :: Conn.t
    def forbidden(conn) do
      conn
      |> put_status(:forbidden)
      |> put_resp_content_type("application/vnd.api+json")
      |> json(
           %Document{
             errors: [
               %Error{
                 detail: "You do not have permission for this resource.",
                 status: "403",
                 title: "Forbidden"
               }
             ]
           }
         )
      |> halt()
    end

    @doc """
    Puts 404 Resource Not Found JSONAPI error in `conn` with `parameter` as the source parameter.
    """
    @spec not_found(Conn.t, String.t) :: Conn.t
    def not_found(conn, parameter) do
      conn
      |> put_status(:not_found)
      |> put_resp_content_type("application/vnd.api+json")
      |> json(
           %Document{
             errors: [
               %Error{
                 source: %Source{
                   parameter: parameter
                 },
                 status: "404",
                 title: "Resource Not Found"
               }
             ]
           }
         )
      |> halt()
    end

    @doc """
    Renders `changeset` as an error object using the `Calcinator.ChangesetView`.
    """
    @spec render_changeset_error(Conn.t, Ecto.Changeset.t) :: Conn.t
    def render_changeset_error(conn, changeset) do
      conn
      |> put_status(:unprocessable_entity)
      |> put_resp_content_type("application/vnd.api+json")
      |> render(ChangesetView, "error-object.json", changeset)
      |> halt()
    end

    @doc """
    Renders `encodable` as JSON after `put_jsonapi_and_status` on the `conn`.
    """
    @spec render_json(Conn.t, term, atom) :: Conn.t
    def render_json(conn, encodable, status) do
      conn
      |> put_status(status)
      |> put_resp_content_type("application/vnd.api+json")
      |> json(encodable)
      |> halt()
    end
  end
end
