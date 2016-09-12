defmodule Calcinator.Controller.Rpc do
  @moduledoc """
  Controller that replicates [`JSONAPI::ActsAsResourceController`](http://www.rubydoc.info/gems/jsonapi-resources/
  JSONAPI/ActsAsResourceController), by delegating to an `Retort.Client.Generic`.
  """

  alias Alembic.Document
  alias Alembic.Pagination
  alias Alembic.ToEctoSchema
  alias Alembic.ToParams
  alias Calcinator.Controller.Authorization
  alias Calcinator.Rpc.Client
  alias Calcinator.Rpc.Meta
  alias Calcinator.Rpc.Response
  alias Plug.Conn

  require Logger

  import Calcinator.Controller
  import Phoenix.Controller
  import Conn

  # Constants

  @default_rpc_timeout 5_000 # milliseconds (same as `Retort.Client.Generic`)

  # Struct

  defstruct callback_module: nil,
            changeset_function: :changeset,
            ecto_schema_module_by_type: %{},
            queue: nil,
            type: nil

  # Types

  @type params :: map

  @typedoc """
  * `callback_module` - Module implementing the `Calcinator.Controller.Rpc` behaviour
  * `changeset_function` - function to call the on `Ecto.Schema` module from `ecto_schema_module_by_type` for `type`
  * `ecto_schema_module_by_type` - Maps JSON API `type` field to the corresponding Ecto.Schema Module for building
    resources from `Calcinator.Rpc.Response` results.
  * `:queue` - The name of the queue on which this controller's client publishes requests.
  * `type` - Primary type.  Used to look up the Ecto.Schema Module in `ecto_schema_module_by_type`.
  """
  @type t :: %__MODULE__{
               callback_module: module,
               changeset_function: atom,
               ecto_schema_module_by_type: ToEctoSchema.ecto_schema_module_by_type,
               queue: Client.Generic.queue,
               type: String.t
             }

  # Callbacks

  @doc """
  Renders response error to `conn` if RPC call fails; otherwise, returns success result for caller to handle.

  ## Overriding

  Override to change `args` to add additional parameters, such as `include`.
  """
  @callback rpc(conn :: Conn.t,
                function :: atom,
                client_pid :: pid,
                args :: list) :: Conn.t |
                                 :ok |
                                 Enumerable.t |
                                 {:ok, struct} |
                                 {:ok, [struct], Pagination.t}

  # Macros

  defmacro __using__(opts) do
    {names, _} = opts
                 |> Keyword.fetch!(:actions)
                 |> Code.eval_quoted([], __CALLER__)
    quoted_configuration = Keyword.fetch!(opts, :configuration)
    {configuration = %__MODULE__{}, []} = Code.eval_quoted(quoted_configuration, [], __CALLER__)

    full_configuration = case configuration do
      %__MODULE__{callback_module: nil} ->
        %{configuration | callback_module: __CALLER__.module}
      _ ->
        configuration
    end

    for name <- names do
      name_quoted_action = quoted_action(name)
      Module.eval_quoted __CALLER__.module, name_quoted_action, [], __CALLER__
    end

    quote do
      alias Calcinator.Controller.Rpc

      @spec rpc(conn :: Conn.t,
                function :: atom,
                client_pid :: pid,
                args :: list) :: Conn.t |
                                 :ok |
                                 Enumerable.t |
                                 {:ok, struct} |
                                 {:ok, [struct], Pagination.t}
      def rpc(conn = %Conn{}, function, client_pid, args) when is_atom(function) and is_list(args) do
        Rpc.rpc(conn, function, client_pid, args)
      end

      @spec rpc_timeout(function :: atom) :: timeout
      def rpc_timeout(function) when is_atom(function), do: Rpc.rpc_timeout(function, __configuration__)

      def __configuration__, do: unquote(Macro.escape(full_configuration))

      defoverridable [rpc: 4, rpc_timeout: 1]
    end
  end

  # Functions

  @doc """
  The `rpc_timeout` as configured for `:calcinator` `key`
  """
  @spec env_rpc_timeout(key :: atom) :: timeout | Keyword.t
  def env_rpc_timeout(key) do
    :calcinator
    |> Application.get_env(key, [])
    |> Keyword.get(:rpc_timeout, @default_rpc_timeout)
  end

  @doc """
  Renders response error to `conn` if RPC call fails; otherwise, returns success result for caller to handle.
  """
  @spec rpc(conn :: Conn.t,
            function :: atom,
            client_pid :: pid,
            args :: list) :: Conn.t |
                             :ok |
                             Enumerable.t |
                             {:ok, struct} |
                             {:ok, [struct], Pagination.t}
  def rpc(conn = %Conn{}, function, client_pid, args) when is_atom(function) and is_list(args) do
    with {:error, error} <- apply(Client.Generic, function, [client_pid | args]) do
      render_response_error(conn, error)
    end
  end

  @doc """
  The timeout for `rpc/4` calls using the specific `function`
  """
  @spec rpc_timeout(function :: atom, t) :: timeout
  def rpc_timeout(function, %__MODULE__{callback_module: callback_module}) do
    case env_rpc_timeout(callback_module) do
      keyword when is_list(keyword) ->
        Keyword.get(keyword, function, @default_rpc_timeout)
      timeout when is_integer(timeout) or timeout == :infinity ->
        timeout
    end
  end

  ## Action Functions

  @spec create(Conn.t, params, t) :: Conn.t
  def create(conn = %Conn{assigns: %{user: user}},
             params,
             configuration = %__MODULE__{callback_module: callback_module}) do
    ecto_schema_module = ecto_schema_module!(configuration)

    with true <- Authorization.can(conn, user, :create, ecto_schema_module),
         {:ok, document} <- document_from_json(conn, params, :create) do

      insertable_params = document
                          |> Document.to_params
                          |> ToParams.nested_to_foreign_keys(ecto_schema_module)

      create_changeset = ecto_schema_module.__struct__
                         |> changeset(insertable_params, configuration)
                         |> changeset(user, configuration)

      if create_changeset.valid? do
        with true <- Authorization.can(conn, user, :create, create_changeset),
             {:ok, client_pid} <- client(conn, configuration),
             create_mergable_params = mergable_params(params),
             {:ok, inserted} <- callback_module.rpc(
                                  conn,
                                  :create,
                                  client_pid,
                                  [
                                    insertable_params,
                                    create_mergable_params,
                                    callback_module.rpc_timeout(:create)
                                  ]
                                ) do
          opts = params_to_render_opts(params)

          conn
          |> put_status(:created)
          |> render("show.json-api", data: inserted, opts: opts)
        end
      else
        render_changeset_error(conn, create_changeset)
      end
    end
  end

  @spec delete(Conn.t, params, t) :: Conn.t
  def delete(conn = %Conn{assigns: %{user: user}},
             %{"id" => id},
             configuration = %__MODULE__{callback_module: callback_module}) do
    with {:ok, client_pid} <- client(conn, configuration),
         {:ok, resource} <- callback_module.rpc(conn, :show, client_pid, [id, %{}, callback_module.rpc_timeout(:show)]),
         true <- Authorization.can(conn, user, :delete, resource),
         :ok <- callback_module.rpc(conn, :destroy, client_pid, [id, callback_module.rpc_timeout(:destroy)]) do
      deleted(conn)
    end
  end

  # There is no get_related_resource function because none of the current resources that use RPC client expose their
  # related resources

  @spec index(Conn.t, params, t) :: Conn.t
  def index(conn = %Conn{assigns: %{user: user}},
            params,
            configuration = %__MODULE__{callback_module: callback_module}) do
    ecto_schema_module = ecto_schema_module!(configuration)

    with true <- Authorization.can(conn, user, :index, ecto_schema_module),
         {:ok, client_pid} <- client(conn, configuration),
         {:ok, resources, pagination} <- callback_module.rpc(conn,
                                                             :index,
                                                             client_pid,
                                                             [
                                                               params,
                                                               callback_module.rpc_timeout(:index)
                                                             ]) do
      authorized_resources = resources
                             # Filter out models that can't be shown
                             |> Authorization.filter_can(user, :show)
                             # Filter out preloaded models
                             |> Authorization.filter_associations_can(user, :show)
      opts = params_to_render_opts(params)

      render(conn, data: authorized_resources, opts: opts, pagination: pagination)
    end
  end

  @spec show(Conn.t, params, t) :: Conn.t
  def show(conn = %Conn{assigns: %{user: user}},
           params = %{"id" => id},
           configuration = %__MODULE__{callback_module: callback_module}) do
    with {:ok, client_pid} <- client(conn, configuration),
         {:ok, resource} <- callback_module.rpc(conn,
                                                :show,
                                                client_pid,
                                                [
                                                  id,
                                                  Map.drop(params, ["id"]),
                                                  callback_module.rpc_timeout(:show)
                                                ]),
         true <- Authorization.can(conn, user, :show, resource) do
      opts = params_to_render_opts(params)
      filtered = Authorization.filter_associations_can(resource, user, :show)

      render(conn, data: filtered, opts: opts)
    end
  end

  @spec update(Conn.t, params, t) :: Conn.t
  def update(conn = %Conn{assigns: %{user: user}},
             params = %{"id" => id},
             configuration = %__MODULE__{callback_module: callback_module}) do
    with {:ok, client_pid} <- client(conn, configuration),
         {:ok, updatable_params} <- authorized_updatable_params(conn, params, configuration, client_pid),
         {:ok, updated} <- callback_module.rpc(conn,
                                               :update,
                                               client_pid,
                                               [
                                                 id,
                                                 updatable_params,
                                                 Map.drop(params, ["data", "id"]),
                                                 callback_module.rpc_timeout(:update)
                                               ]) do
      opts = params_to_render_opts(params)
      filtered = Authorization.filter_associations_can(updated, user, :show)

      render(conn, "show.json-api", data: updated, opts: opts)
    end
  end

  ## Private Functions

  defp authorized_updatable_params(conn = %Conn{assigns: %{user: user}},
                                   params = %{"id" => id},
                                   configuration = %__MODULE__{callback_module: callback_module},
                                   client_pid) do
     # Can't do a direct Client.Generic.update call because authorizaton needs to be applied first
     with {:ok, resource} <- callback_module.rpc(conn,
                                                 :show,
                                                 client_pid,
                                                 [id, %{}, callback_module.rpc_timeout(:show)]),
          # if you can't show the current state of the resources there's no reason you should be able to update it
          true <- Authorization.can(conn, user, :show, resource),
          {:ok, updatable_params} <- updatable_params_from_json(conn, params, resource),
          update_changeset = changeset(resource, updatable_params, configuration),
          true <- Authorization.can(conn, user, :update, update_changeset) do
       {:ok, updatable_params}
     end
  end

  defp changeset(model, input, configuration = %__MODULE__{changeset_function: changeset_function}) do
    ecto_schema_module = ecto_schema_module!(configuration)
    apply(ecto_schema_module, changeset_function, [model, input])
  end

  # `with`able form of `client/1` that should continue only if `{:ok, client_pid}` is returned
  defp client(conn = %Conn{},
              %__MODULE__{ecto_schema_module_by_type: ecto_schema_module_by_type, queue: queue, type: type}) do
    meta = Meta.valid!(conn.params["meta"], %{ecto_schema_modules: Map.values(ecto_schema_module_by_type)})
    client_opts = [
      ecto_schema_module_by_type: ecto_schema_module_by_type,
      queue: queue,
      type: type
    ]

    full_client_opts = case meta do
      nil ->
        client_opts
      _ ->
        [{:meta, meta} | client_opts]
    end

    case Client.Generic.start_link(full_client_opts) do
      continue = {:ok, _} ->
        continue
      {:error, reason} ->
        Logger.error("Could not start RPC Client due to #{reason}")

        conn
        |> put_resp_content_type("application/vnd.api+json")
        |> send_resp(:bad_gateway, "")
    end
  end

  defp ecto_schema_module!(%__MODULE__{ecto_schema_module_by_type: ecto_schema_module_by_type, type: type}) do
    Map.fetch!(ecto_schema_module_by_type, type)
  end

  defp mergable_params(params) when is_map(params) do
    Map.drop(params, %Document{} |> Map.keys |> Enum.map(&to_string/1))
  end

  defp quoted_action(quoted_name) do
    quote do
      def unquote(quoted_name)(conn, params) do
        Calcinator.Controller.Rpc.unquote(quoted_name)(conn, params, __configuration__)
      end
    end
  end

  defp render_response_error(conn, %Response.Error{data: document = %Document{}}) do
    status = case Document.error_status_consensus(document) do
      nil ->
        :unprocessable_entity
      error_status ->
        String.to_integer(error_status)
    end

    render_json(conn, document, status)
  end

  defp render_response_error(conn, error = %Response.Error{}), do: render_json(conn, error, :unprocessable_entity)

  defp updatable_params_from_json(conn, params, resource) do
    # Unfortunately have to parse the params into a document so a changeset can be created for authorization
    with {:ok, document} <- document_from_json(conn, params, :update) do
      updatable_params = document
                         |> Document.to_params
                         |> ToParams.nested_to_foreign_keys(resource.__struct__)

      {:ok, updatable_params}
    end
  end
end
