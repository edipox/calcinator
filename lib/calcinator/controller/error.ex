if Code.ensure_loaded?(Phoenix.Controller) do
  defmodule Calcinator.Controller.Error do
    @moduledoc """
    Errors returned by `Calcinator.Controller`.  Public, so that other controllers not using `Calcinator.Controller` can
    have same format for errors.
    """

    alias Alembic.{Document, Error, Source}
    alias Calcinator.ChangesetView
    alias Plug.Conn

    require Logger

    import Conn, only: [halt: 1, put_resp_content_type: 2, put_status: 2, send_resp: 3]
    import Phoenix.Controller, only: [json: 2, render: 4]

    @doc """
    Retort returned a 500 JSONAPI error inside a 422 JSONRPC error.
    """
    @spec bad_gateway(Conn.t) :: Conn.t
    def bad_gateway(conn) do
      render_json conn,
                  %Document{
                    errors: [
                      %Error{
                        status: "502",
                        title: "Bad Gateway"
                      }
                    ]
                  },
                  :bad_gateway
    end

    @doc """
    The resource was deleted
    """
    @spec deleted(Conn.t) :: Conn.t
    def deleted(conn) do
      conn
      |> put_resp_content_type()
      |> send_resp(:no_content, "")
    end

    @doc """
    The current resource or action is forbidden to the authenticated user
    """
    @spec forbidden(Conn.t) :: Conn.t
    def forbidden(conn) do
      render_json conn,
                  %Document{
                    errors: [
                      %Error{
                        detail: "You do not have permission for this resource.",
                        status: "403",
                        title: "Forbidden"
                      }
                    ]
                  },
                  :forbidden
    end

    @doc """
    Puts 504 Gateway Timeout JSONAPI error in `conn`.
    """
    @spec gateway_timeout(Conn.t) :: Conn.t
    def gateway_timeout(conn) do
      render_json conn,
                  %Document{
                    errors: [
                      %Error{
                        status: "504",
                        title: "Gateway Timeout"
                      }
                    ]
                  },
                  :gateway_timeout
    end

    @doc """
    Puts 404 Resource Not Found JSONAPI error in `conn` with `parameter` as the source parameter.
    """
    @spec not_found(Conn.t, String.t) :: Conn.t
    def not_found(conn, parameter) do
      render_json conn,
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
                  },
                  :not_found
    end

    @doc """
    Puts 500 Internal Server Error JSONAPI error in `conn` with title `"Ownership Error"`.
    """
    @spec ownership_error(Conn.t) :: Conn.t
    def ownership_error(conn) do
      render_json conn,
                   %Document{
                     errors: [
                       %Error{
                         detail: "Owner of backing store connection could not be found",
                         status: "500",
                         title: "Ownership Error"
                       }
                     ]
                   },
                   # DBConnection.OwnershipError raised when the connection was checked out from the pool too long and
                   # the lease was # revoked.  This could be a 504 Gateway Timeout, but that pool is inside Elixir and
                   # not part of the Database # itself, so keeping as 500 Internal Server Error.  504 Gateway Timeout is
                   # also not accurate, because the # "gateway" is responding, it's just saying you can't do it.
                   #
                   # See 5XX section of http://racksburg.com/choosing-an-http-status-code/
                   :internal_server_error
    end

    @doc """
    Puts JSONAPI Content Type in the Response of the `conn`
    """
    def put_resp_content_type(conn), do: put_resp_content_type(conn, "application/vnd.api+json")

    @doc """
    Converts an error `reason` from that isn't a standard format (such as those from the backing store) to a
    500 Internal Server Error JSONAPI error, but with `id` set to `id` that is also used in `Logger.error`, so that
    `reason`, which should remain private to limit implementation disclosures that could lead to security issues.

    ## Log Messages

    ```
    id=UUIDv4 reason=inspect(reason)
    ```

    ## Returns

      * `Plug.Conn.t` - The `Plug.Conn.t` is halted with `Plug.Conn.halt/1`

    """
    @spec render_error_reason(Conn.t, reason :: term) :: Conn.t
    def render_error_reason(conn, reason) do
      id = UUID.uuid4()

      Logger.error fn ->
        "id=#{id} reason=#{inspect(reason)}"
      end

      document = %Document{
        errors: [
          %Error{
            id: id,
            status: "500",
            title: "Internal Server Error"
          }
        ]
      }

      render_json(conn, document, :internal_server_error)
    end

    @doc """
    Renders `changeset` as an error object using the `Calcinator.ChangesetView`.
    """
    @spec render_changeset_error(Conn.t, Ecto.Changeset.t) :: Conn.t
    def render_changeset_error(conn, changeset) do
      conn
      |> put_status(:unprocessable_entity)
      |> put_resp_content_type()
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
      |> put_resp_content_type()
      |> json(encodable)
      |> halt()
    end

    @doc """
    Puts 422 Unprocessable Entity JSONAPI error in `conn` with title `"Sandbox Access Disallowed".
    """
    @spec sandbox_access_disallowed(Conn.t) :: Conn.t
    def sandbox_access_disallowed(conn) do
      render_json conn,
                  %Document{
                    errors: [
                      %Error{
                        detail: "Information in /meta/beam was not enough to grant access to the sandbox",
                        source: %Source{
                          pointer: "/meta/beam"
                        },
                        status: "422",
                        title: "Sandbox Access Disallowed"
                      }
                    ]
                  },
                  :unprocessable_entity
    end

    @doc """
    Puts 422 Unrpcessable Entity JSONAPI error in `conn` with title `"Child missing".
    """
    @spec sandbox_token_missing(Conn.t) :: Conn.t
    def sandbox_token_missing(conn) do
      render_json conn,
                  %Document{
                    errors: [
                      Error.missing(
                        %Error{
                          source: %Source{
                            pointer: "/meta"
                          }
                        },
                        "beam"
                      )
                    ]
                  },
                  :unprocessable_entity
    end
  end
end
