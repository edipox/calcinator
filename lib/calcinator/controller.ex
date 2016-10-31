defmodule Calcinator.Controller do
  @moduledoc """
  Controller that replicates [`JSONAPI::ActsAsResourceController`](http://www.rubydoc.info/gems/jsonapi-resources/
  JSONAPI/ActsAsResourceController).
  """

  alias Alembic.Document
  alias Plug.Conn

  import Conn

  # Macros

  defmacro __using__(opts) do
    {names, _} = opts
                 |> Keyword.fetch!(:actions)
                 |> Code.eval_quoted([], __CALLER__)
    quoted_configuration = Keyword.fetch!(opts, :configuration)

    for name <- names do
      name_quoted_action = quoted_action(name, quoted_configuration)
      Module.eval_quoted __CALLER__.module, name_quoted_action, [], __CALLER__
    end
  end

  # Functions

  @spec create(Conn.t, Calcinator.params, Calcinator.t) :: Conn.t
  def create(conn = %Conn{assigns: %{user: user}},
             params,
             calcinator = %Calcinator{}) do
    case Calcinator.create(%Calcinator{calcinator | subject: user}, params) do
      {:ok, rendered} ->
        conn
        |> put_status(:created)
        |> put_resp_content_type("application/vnd.api+json")
        |> send_resp(:created, Poison.encode!(rendered))
      {:error, :unauthorized} ->
        forbidden(conn)
      {:error, changeset = %Ecto.Changeset{}} ->
        render_changeset_error(conn, changeset)
      {:error, document = %Document{}} ->
        render_json(conn, document, :unprocessable_entity)
    end
  end

  @spec delete(Conn.t, Calcinator.params, Calcinator.t) :: Conn.t
  def delete(conn = %Conn{assigns: %{user: user}},
             params = %{"id" => _},
             calcinator = %Calcinator{}) do
    case Calcinator.delete(%Calcinator{calcinator | subject: user}, params) do
      :ok ->
        conn
        |> put_resp_content_type("application/vnd.api+json")
        |> send_resp(:no_content, "")
      {:error, {:not_found, parameter}} ->
        not_found(conn, parameter)
      {:error, :unauthorized} ->
        forbidden(conn)
    end
  end

  @spec get_related_resource(Conn.t, Calcinator.params, Calcinator.t) :: Conn.t
  def get_related_resource(
        conn = %Conn{
          assigns: %{
            related: related,
            source: source,
            user: user
          }
        },
        params,
        calcinator = %Calcinator{}
      ) do
    case Calcinator.get_related_resource(
           %Calcinator{calcinator | subject: user},
           params,
           %{
             related: related,
             source: source
           }
         ) do
      {:ok, rendered} ->
        conn
        |> put_status(:ok)
        |> put_resp_content_type("application/vnd.api+json")
        |> send_resp(:ok, Poison.encode!(rendered))
      {:error, {:not_found, parameter}} ->
        not_found(conn, parameter)
      {:error, :unauthorized} ->
        forbidden(conn)
    end
  end

  @spec index(Conn.t, Calcinator.params, Calcinator.t) :: Conn.t
  def index(conn = %Conn{assigns: %{user: user}},
            params,
            calcinator = %Calcinator{}) do
    case Calcinator.index(%Calcinator{calcinator | subject: user}, params, %{base_uri: base_uri(conn)}) do
      {:ok, rendered} ->
        conn
        |> put_status(:ok)
        |> put_resp_content_type("application/vnd.api+json")
        |> send_resp(:ok, Poison.encode!(rendered))
      {:error, :unauthorized} ->
        forbidden(conn)
      {:error, document = %Document{}} ->
         render_json(conn, document, :unprocessable_entity)
    end
  end

  @spec show(Conn.t, Calcinator.params, Calcinator.t) :: Conn.t
  def show(conn = %Conn{assigns: %{user: user}},
           params = %{"id" => _},
           calcinator = %Calcinator{}) do
     case Calcinator.show(%Calcinator{calcinator | subject: user}, params) do
       {:ok, rendered} ->
         conn
         |> put_status(:ok)
         |> put_resp_content_type("application/vnd.api+json")
         |> send_resp(:ok, Poison.encode!(rendered))
       {:error, {:not_found, parameter}} ->
         not_found(conn, parameter)
       {:error, :unauthorized} ->
         forbidden(conn)
       {:error, document = %Document{}} ->
         render_json(conn, document, :unprocessable_entity)
     end
  end

  @spec show_relationship(Conn.t, Calcinator.params, Calcinator.t) :: Conn.t
  def show_relationship(
        conn = %Conn{
          assigns: %{
            related: related,
            source: source,
            user: user
          }
        },
        params,
        calcinator = %Calcinator{}
      ) do
    case Calcinator.show_relationship(
           %Calcinator{calcinator | subject: user},
           params,
           %{related: related, source: source}
         ) do
      {:ok, rendered} ->
        conn
        |> put_status(:ok)
        |> put_resp_content_type("application/vnd.api+json")
        |> send_resp(:ok, Poison.encode!(rendered))
      {:error, {:not_found, parameter}} ->
        not_found(conn, parameter)
      {:error, :unauthorized} ->
        forbidden(conn)
    end
  end

  @spec update(Conn.t, Calcinator.params, Calcinator.t) :: Conn.t
  def update(
        conn = %Conn{
          assigns: %{
            user: user
          }
        },
        params,
        calcinator = %Calcinator{}
      ) do
     case Calcinator.update(%Calcinator{calcinator | subject: user}, params) do
       {:ok, rendered} ->
         conn
         |> put_status(:ok)
         |> put_resp_content_type("application/vnd.api+json")
         |> send_resp(:ok, Poison.encode!(rendered))
       {:error, {:not_found, parameter}} ->
         not_found(conn, parameter)
       {:error, :unauthorized} ->
         forbidden(conn)
       {:error, changeset = %Ecto.Changeset{}} ->
         render_changeset_error(conn, changeset)
       {:error, document = %Document{}} ->
         render_json(conn, document, :unprocessable_entity)
     end
  end

  ## Private Functions

  defp base_uri(%Conn{request_path: path}), do: %URI{path: path}

  defp quoted_action(quoted_name, quoted_configuration) do
    quote do
      def unquote(quoted_name)(conn, params) do
        Calcinator.Controller.unquote(quoted_name)(conn, params, unquote(quoted_configuration))
      end
    end
  end
end
