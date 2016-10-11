defmodule Calcinator.Controller.Ecto do
  @moduledoc """
  Controller that replicates [`JSONAPI::ActsAsResourceController`](http://www.rubydoc.info/gems/jsonapi-resources/
  JSONAPI/ActsAsResourceController).
  """

  alias Alembic.{Document, Fetch, Fetch.Includes, Source, ToParams}
  alias Calcinator.Controller.{Authorization, Ecto.Query}
  alias Calcinator.Repo
  alias Plug.Conn

  import Calcinator.Controller
  import Phoenix.Controller
  import Conn

  # Struct

  defstruct before_authorization_preload: [],
            changeset_function: :changeset,
            ecto_schema: nil,
            preload: [],
            preload_by_include: %{}

  # Types

  @type params :: map

  @typedoc """
  * `before_authorization_preload` - preloads to load with `Repo.preload` before running authorization checks.
  * `changeset_function` - function to call on `ecto_schema` to create an `Ecto.Changeset.t`
  * `ecto_schema` - `Ecto.Schema.t` module that has `changeset/3`
  * `preload` - preload that is always included
  * `preload_by_include` - translates relationship names and paths to association preloads
  """
  @type t :: %__MODULE__{
               before_authorization_preload: Includes.preload,
               changeset_function: atom,
               ecto_schema: module,
               preload: Includes.preload,
               preload_by_include: Includes.preload_by_include
             }

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

  @spec create(Conn.t, params, t) :: Conn.t
  def create(conn = %Conn{assigns: %{user: user}},
             params,
             configuration = %__MODULE__{
               ecto_schema: ecto_schema,
               preload: preload,
               preload_by_include: preload_by_include
             }) do
    with true <- Authorization.can(conn, user, :create, ecto_schema),
         {:ok, valid_changeset} <- valid_create_changeset(conn, params, configuration),
         {:ok, preloads} <- preloads_from_include_param(conn, params, preload_by_include),
         true <- Authorization.can(conn, user, :create, valid_changeset),
         {:ok, inserted} <- mutate_repo(conn, :insert, valid_changeset) do
      inserted_preloaded = Repo.preload(inserted, preloads ++ preload)
      opts = params_to_render_opts(params)

      conn
      |> put_status(:created)
      |> render("show.json-api", data: inserted_preloaded, opts: opts)
    end
  end

  @spec delete(Conn.t, params, t) :: Conn.t
  def delete(conn = %Conn{assigns: %{user: user}},
             %{"id" => id},
             configuration = %__MODULE__{ecto_schema: ecto_schema}) do
    with got = %{__struct__: ^ecto_schema} <- get(conn, id, configuration),
         true <- Authorization.can(conn, user, :delete, got) do
      Repo.delete!(got)

      deleted(conn)
    end
  end

  @spec get_related_resource(Conn.t, params, t) :: Conn.t
  def get_related_resource(conn = %Conn{assigns: %{user: user, source: %{id_key: source_id_key}}},
                           params,
                           configuration = %__MODULE__{preload_by_include: preload_by_include}) do
    case get_source(conn, params, configuration) do
      nil ->
        not_found(conn, source_id_key)
      source ->
        # if you can't the see the source, then you can't see its related resources
        with true <- Authorization.can conn, user, :show, source do
          case conn |> Query.related(params, configuration) |> Repo.one do
            nil ->
              render(conn, data: nil)
            shown ->
              with true <- Authorization.can(conn, user, :show, [shown, source]),
                   {:ok, preloads} <- preloads_from_include_param(conn, params, preload_by_include) do
                preloaded_shown = Repo.preload(shown, preloads)
                opts = params_to_render_opts(params)
                filtered = Authorization.filter_associations_can(preloaded_shown, [source], user, :show)

                render(conn, data: filtered, opts: opts)
              end
          end
        end
    end
  end

  @spec index(Conn.t, params, t) :: Conn.t
  def index(conn = %Conn{assigns: %{user: user}},
            params,
            configuration = %__MODULE__{
              before_authorization_preload: before_authorization_preload,
              ecto_schema: ecto_schema,
              preload: preload
            }) do
    with true <- Authorization.can(conn, user, :index, ecto_schema),
         {:ok, query} <- query_from_params(conn, params, configuration) do
      all = query
           |> Repo.all
           |> Repo.preload(before_authorization_preload)
           # filter out models that can't be shown before preloading to remove unnecessary preloading
           |> Authorization.filter_can(user, :show)
           |> Repo.preload(preload)
           # filter out preloaded models now that their ids are known
           |> Authorization.filter_associations_can(user, :show)
      render(conn, data: all)
    end
  end

  @spec show(Conn.t, params, t) :: Conn.t
  def show(conn = %Conn{assigns: %{user: user}},
           params = %{"id" => id},
           configuration = %__MODULE__{ecto_schema: ecto_schema, preload_by_include: preload_by_include}) do
    with shown = %{__struct__: ^ecto_schema} <- get(conn, id, configuration),
         true <- Authorization.can(conn, user, :show, shown),
         {:ok, preloads} <- preloads_from_include_param(conn, params, preload_by_include) do
      preloaded_shown = Repo.preload(shown, preloads)
      opts = params_to_render_opts(params)
      filtered = Authorization.filter_associations_can(preloaded_shown, user, :show)

      render(conn, data: filtered)
    end
  end

  @spec show_relationship(Conn.t, params, t) :: Conn.t
  def show_relationship(conn = %Conn{assigns: %{user: user}},
                        params,
                        configuration = %__MODULE__{ecto_schema: ecto_schema}) do
    with owner = %{__struct__: ^ecto_schema} <- get_owner(conn, params, configuration),
         # if you can't the see the source, then you can't see its related resources
         true <- Authorization.can(conn, user, :show, owner) do
      case relationship(conn, Query.relationship(conn, params, configuration), configuration) do
        nil ->
          rendered = render(conn, data: nil)
        related ->
          with true <- Authorization.can(conn, user, :show, [related, owner]) do
            filtered = Authorization.filter_associations_can(related, [owner], user, :show)

            render(conn, data: filtered)
          end
      end
    end
  end

  @spec update(Conn.t, params, t) :: Conn.t
  def update(conn = %Conn{assigns: %{user: user}},
             params = %{"id" => id},
             configuration = %__MODULE__{
               ecto_schema: ecto_schema,
               preload: preload,
               preload_by_include: preload_by_include
             }) do
    with updatable = %{__struct__: ^ecto_schema} <- get(conn, id, configuration),
         {:ok, document} <- document_from_json(conn, params, :update) do
      updatable_params = document
                         |> Document.to_params
                         |> ToParams.nested_to_foreign_keys(ecto_schema)
      update_changeset = changeset(updatable, updatable_params, configuration)

      with true <- Authorization.can(conn, user, :update, update_changeset),
           # check includes are valid before Repo.update even though the calculated `preloads` are used
           # post-`Repo.update`, so that an update doesn't occur, but then an error is returned because the
           # `include`s are bad
           {:ok, preloads} <- preloads_from_include_param(conn, params, preload_by_include),
           {:ok, updated} <- mutate_repo(conn, :update, update_changeset) do
        preloaded_updated = Repo.update_preload(updated, preloads ++ preload)
        opts = params_to_render_opts(params)
        render(conn, "show.json-api", data: preloaded_updated, opts: opts)
      end
    end
  end

  ## Private Functions

  defp changeset(model, input, %__MODULE__{changeset_function: changeset_function, ecto_schema: ecto_schema}) do
    apply(ecto_schema, changeset_function, [model, input])
  end

  defp create_changeset(conn = %Conn{assigns: %{user: user}},
                        params,
                        configuration = %__MODULE__{ecto_schema: ecto_schema}) do
    with {:ok, document} <- document_from_json(conn, params, :create) do
      insertable_params = document
                          |> Document.to_params
                          |> ToParams.nested_to_foreign_keys(ecto_schema)
      maybe_valid_changeset = ecto_schema.__struct__
                              |> changeset(insertable_params, configuration)
                              |> changeset(user, configuration)
      {:ok, maybe_valid_changeset}
    end
  end

  @spec get(id, t) :: struct | nil when id: String.t
  defp get(id, %__MODULE__{ecto_schema: ecto_schema, before_authorization_preload: before_authorization_preload}) do
    with model = %{} <- Repo.get(ecto_schema, id) do
      Repo.preload(model, before_authorization_preload)
    end
  end

  @spec get(Conn.t, id :: String.t, t) :: struct | Conn
  defp get(conn = %Conn{}, id, configuration), do: with(nil <- get(id, configuration), do: not_found(conn, "id"))

  @spec get_owner(Conn.t, params, t) :: struct | nil
  defp get_owner(conn = %Conn{
                   assigns: %{
                     owner: %{
                       before_authorization_preload: before_authorization_preload,
                       id_key: owner_id_key
                     }
                   }
                 },
                 params,
                 %__MODULE__{ecto_schema: ecto_schema}) do
    case Repo.get(ecto_schema, params[to_string(owner_id_key)]) do
      nil ->
        not_found(conn, owner_id_key)
      owner ->
        Repo.preload(owner, before_authorization_preload)
    end
  end

  @spec get_source(Conn.t, params, t) :: struct | nil
  defp get_source(conn = %Conn{
                   assigns: %{
                     source: %{
                       before_authorization_preload: before_authorization_preload
                     }
                   }
                 },
                 params,
                 configuration) do
    with model = %{} <- conn |> Query.source(params, configuration) |> Repo.one do
      Repo.preload(model, before_authorization_preload)
    end
  end

  # Does a `function` mutation to `Repo` that can fail with a changeset error, which will be rendered; otherwise,
  # returns `{:ok, resource}`
  defp mutate_repo(conn = %Conn{}, function, mutation_changeset = %Ecto.Changeset{})
       when function in [:insert, :update] do
    with {:error, error_changeset} <- apply(Repo, function, [mutation_changeset]) do
      render_changeset_error(conn, error_changeset)
    end
  end

  @spec not_found(Conn.t, String.t) :: Conn.t
  defp not_found(conn, parameter) do
    conn
    |> put_jsonapi_and_status(:not_found)
    |> json(
         %Document{
           errors: [
             %Alembic.Error{
               source: %Source{
                 parameter: parameter
               },
               status: "404",
               title: "Resource Not Found"
             }
           ]
         }
       )
  end

  defp preloads_from_include_param(conn, params, preload_by_include) do
   fetch = Fetch.from_params(params)

   with {:error, document} <- Includes.to_preloads(fetch.includes, preload_by_include) do
     render_json(conn, document, :unprocessable_entity)
   end
  end

  defp query_from_params(conn, params, %__MODULE__{preload_by_include: preload_by_include, ecto_schema: ecto_schema}) do
    fetch = Fetch.from_params(params || %{})

    with {:error, document} <- Fetch.to_query(fetch, preload_by_include, ecto_schema) do
     render_json(conn, document, :unprocessable_entity)
    end
  end

  defp quoted_action(quoted_name, quoted_configuration) do
    quote do
      def unquote(quoted_name)(conn, params) do
        Calcinator.Controller.Ecto.unquote(quoted_name)(conn, params, unquote(quoted_configuration))
      end
    end
  end

  @spec relationship(Conn.t, Ecto.Queryable.t, t) :: [struct] | struct | nil
  defp relationship(%Conn{assigns: %{association: association}}, query, %__MODULE__{ecto_schema: ecto_schema}) do
    function = case ecto_schema.__schema__(:association, association) do
      %{cardinality: :one} ->
        :one
      %{cardinality: :many} ->
        :all
    end

    apply(Repo, function, [query])
  end

  defp valid_create_changeset(conn, params, configuration) do
    with {:ok, maybe_valid_changeset} <- create_changeset(conn, params, configuration) do
      if maybe_valid_changeset.valid? do
        {:ok, maybe_valid_changeset}
      else
        render_changeset_error(conn, maybe_valid_changeset)
      end
    end
  end
end
