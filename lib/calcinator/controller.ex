defmodule Calcinator.Controller do
  @moduledoc """
  Controller that replicates [`JSONAPI::ActsAsResourceController`](http://www.rubydoc.info/gems/jsonapi-resources/
  JSONAPI/ActsAsResourceController).
  """

  alias Alembic.Document
  alias Plug.Conn

  import Calcinator.{Authorization, Controller.Error}
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

  @doc """
  Gets the subject used for the `%Calcinator{}` passed to action functions.

      iex> %Plug.Conn{} |>
      iex> Calcinator.Controller.put_subject(:admin) |>
      iex> Calcinator.Controller.get_subject()
      :admin

  It can be `nil` if `put_subject/2` was not called or called `put_subject(conn, nil)`.

      iex> Calcinator.Controller.get_subject(%Plug.Conn{})
      nil
      iex> %Plug.Conn{} |>
      iex> Calcinator.Controller.put_subject(nil) |>
      iex> Calcinator.Controller.get_subject()
      nil

  """
  @spec get_subject(Conn.t) :: Authorization.subject
  def get_subject(conn), do: conn.private[:calcinator_subject]

  @doc """
  Puts the subject used for the `%Calciantor{}` pass to action functions.

  If you use subject-based authorization, where you don't use `Calcinator.Authorization.Subjectless` (the default) for
  the `:authorization` module, then you will need to set the subject.

  Here, the subject is set from the `user` assign set by some authorization plug (not shown)

      defmodule MyAppWeb.PostController do
        alias Calcinator.Controller

        use Controller,
            actions: ~w(create destroy index show update)a,
            configuration: %Calcinator{
              authorization_module: MyAppWeb.Authorization,
              ecto_schema_module: MyApp.Post,
              resources_module: MyApp.Posts,
              view_module: MyAppWeb.PostView
            }

        # Plugs

        plug :put_subject

        # Functions

        def put_subject(conn = %Conn{assigns: %{user: user}}, _), do: Controller.put_subject(conn, user)
      end

  """
  @spec put_subject(Conn.t, Authorization.subject) :: Conn.t
  def put_subject(conn, subject), do: put_private(conn, :calcinator_subject, subject)

  ## Action Functions

  @spec create(Conn.t, Calcinator.params, Calcinator.t) :: Conn.t
  def create(conn = %Conn{}, params, calcinator = %Calcinator{}) do
    case Calcinator.create(%Calcinator{calcinator | subject: get_subject(conn)}, params) do
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
  def delete(conn, params = %{"id" => _}, calcinator = %Calcinator{}) do
    case Calcinator.delete(%Calcinator{calcinator | subject: get_subject(conn)}, params) do
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
            source: source
          }
        },
        params,
        calcinator = %Calcinator{}
      ) do
    case Calcinator.get_related_resource(
           %Calcinator{calcinator | subject: get_subject(conn)},
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
  def index(conn, params, calcinator = %Calcinator{}) do
    case Calcinator.index(%Calcinator{calcinator | subject: get_subject(conn)}, params, %{base_uri: base_uri(conn)}) do
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
  def show(conn, params = %{"id" => _}, calcinator = %Calcinator{}) do
     case Calcinator.show(%Calcinator{calcinator | subject: get_subject(conn)}, params) do
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
            source: source
          }
        },
        params,
        calcinator = %Calcinator{}
      ) do
    case Calcinator.show_relationship(
           %Calcinator{calcinator | subject: get_subject(conn)},
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
  def update(conn, params, calcinator = %Calcinator{}) do
     case Calcinator.update(%Calcinator{calcinator | subject: get_subject(conn)}, params) do
       {:ok, rendered} ->
         conn
         |> put_status(:ok)
         |> put_resp_content_type("application/vnd.api+json")
         |> send_resp(:ok, Poison.encode!(rendered))
       {:error, :bad_gateway} ->
         bad_gateway(conn)
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
