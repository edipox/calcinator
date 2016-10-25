defmodule Calcinator.Resources do
  alias Alembic.{Document, Fetch, Fetch.Includes, FromJson, ToParams, Source}
  alias Calcinator.{Authorization, Meta}

  # Constants

  @actions ~w(create delete index update show)a

  # Struct

  defstruct associations_by_include: %{},
            authorization_module: nil,
            ecto_schema_module: nil,
            params: %{},
            resources_module: nil,
            subject: nil,
            view_module: nil

  # Types

  @type association :: atom | list | map

  @typedoc """
  Nested params format used by `Ecto.Changeset.t`.
  """
  @type insertable_params :: %{String.t => term}

  @typedoc """
  The name of the parameter that was used for the query and was not found.
  """
  @type parameter :: String.t

  @typedoc """
  The raw request params that need to be validated as a JSONAPI document and converted to an `Alembic.Document.t`
  """
  @type params :: %{String.t => term}

  @typedoc """
  A rendered JSONAPI document as a `map`
  """
  @type rendered :: map

  @typedoc """
    * `authorization_module` - The module that implements the `Calcinator.Authorization` behaviour
    * `subject` - the subject that is trying to do the action and needs to be authorized by `authorization_module`
    * `target` - the target of `subject`'s action
  """
  @type t :: %__MODULE__{
               authorization_module: module,
               ecto_schema_module: module,
               subject: Authorization.subject,
               view_module: module
             }

  # Functions

  @spec create(t, params) :: {:error, :unauthorized} |
                             {:error, Document.t} |
                             {:error, Ecto.Changeset.t} |
                             {:ok, rendered}
  def create(state = %__MODULE__{
                       ecto_schema_module: ecto_schema_module,
                       subject: subject,
                       view_module: view_module
                     },
             params)
      when not is_nil(ecto_schema_module) and is_atom(ecto_schema_module) and
           not is_nil(view_module) and is_atom(view_module) and
           is_map(params) do
    with :ok <- can(state, :create, ecto_schema_module),
         {:ok, document} <- document(params, :create),
         insertable_params = insertable_params(state, document),
         {:ok, changeset} <- changeset(state, insertable_params),
         :ok <- can(state, :create, changeset),
         {:ok, created} <- create_changeset(state, changeset, params) do
      authorized = authorized(state, created)
      {:ok, view_module.show(authorized, %{params: params, subject: subject})}
    end
  end

  @spec delete(t, params) ::
        {:error, {:not_found, parameter}} | {:error, :unauthorized} | {:error, Ecto.Changeset.t} | :ok
  def delete(state = %__MODULE__{}, params) do
    with :ok <- allow_sandbox_access(state, params),
         {:ok, target} <- get(state, params),
         :ok <- can(state, :delete, target),
         {:ok, _deleted} <- delete_ecto_schema(state, target) do
      :ok
    end
  end

  @spec get_related_resource(t, params, map) ::
        {:error, {:not_found, parameter}} | {:error, :unauthorized} | {:ok, rendered}
  def get_related_resource(
        state = %__MODULE__{},
        params,
        options = %{related: related}
      ) do
    related_property(state, params, put_in(options.related, Map.put(related, :property, :resource)))
  end

  @spec index(t, params) :: {:error, :unauthorized} | {:ok, rendered}
  def index(state = %__MODULE__{
                      ecto_schema_module: ecto_schema_module,
                      subject: subject,
                      view_module: view_module,
                    },
            params) do
    with :ok <- can(state, :index, ecto_schema_module),
         :ok <- allow_sandbox_access(state, params),
         {:ok, list, pagination} <- list(state, params) do
      {authorized, authorized_pagination} = authorized(state, list, pagination)
      {:ok, view_module.index(authorized, %{pagination: authorized_pagination, params: params, subject: subject})}
    end
  end

  @spec show(t, params) ::
        {:error, {:not_found, parameter}} | {:error, :unauthorized} | {:error, Document.t} | {:ok, rendered}
  def show(state = %__MODULE__{subject: subject, view_module: view_module}, params = %{"id" => _}) do
    with :ok <- allow_sandbox_access(state, params),
         {:ok, shown} <- get(state, params),
         :ok <- can(state, :show, shown) do
      authorized = authorized(state, shown)
      {:ok, view_module.show(authorized, %{params: params, subject: subject})}
    end
  end

  @spec show_relationship(t, params, map) ::
        {:error, {:not_found, parameter}} | {:error, :unauthorized} | {:ok, rendered}
  def show_relationship(
        state = %__MODULE__{},
        params,
        options = %{related: related}
      ) do
    related_property(state, params, put_in(options.related, Map.put(related, :property, :relationship)))
  end

  @spec update(t, params) :: {:error, {:not_found, parameter}} |
                             {:error, :unauthorized} |
                             {:error, Document.t} |
                             {:error, Ecto.Changeset.t} |
                             {:ok, rendered}
  def update(state = %__MODULE__{subject: subject, view_module: view_module}, params) do
    with :ok <- allow_sandbox_access(state, params),
         {:ok, updatable} <- get(state, params),
         :ok <- can(state, :show, updatable),
         {:ok, document} <- document(params, :update),
         updatable_params = insertable_params(state, document),
         {:ok, changeset} <- changeset(state, updatable, updatable_params),
         :ok <- can(state, :update, changeset),
         {:ok, updated} <- update_changeset(state, changeset, params) do
      # DO NOT `:ok <- can(state, :show, updated)` because user can update to attributees they can't view, but we need
      # to send back the updated resource
      authorized = authorized(state, updated)
      {:ok, view_module.show(authorized, %{params: params, subject: subject})}
    end
  end

  ## Private Functions

  def allow_sandbox_access(state = %__MODULE__{resources_module: resources_module}, params) do
    allow_sandbox_access(state, params, resources_module.sandboxed?())
  end

  def allow_sandbox_access(
        %__MODULE__{resources_module: resources_module},
        %{
          "meta" => %{
            "beam" => encoded_beam_meta
          }
        },
        true
      ) when is_binary(encoded_beam_meta) do
    encoded_beam_meta
    |> Meta.Beam.decode
    |> resources_module.allow_sandbox_access()
  end

  def allow_sandbox_access(%__MODULE__{}, params,  true) when is_map(params), do: {:error, :sandbox_token_missing}
  def allow_sandbox_access(%__MODULE__{}, params, false) when is_map(params), do: :ok

  # Filters a related resource that does not exist
  def authorized(%__MODULE__{}, nil), do: nil

  # Filters `struct` or list of `struct`s to only those that can be shown
  @spec authorized(t, struct) :: struct
  def authorized(%__MODULE__{authorization_module: authorization_module, subject: subject}, unfiltered = %_{}) do
    authorization_module.filter_associations_can(unfiltered, subject, :show)
  end

  @spec authorized(t, [struct], Resources.pagination) :: {[struct], Resources.pagination}
  def authorized(%__MODULE__{authorization_module: authorization_module, subject: subject}, unfiltered, pagination)
      when is_list(unfiltered) and
          (is_nil(pagination) or is_map(pagination)) do
    {shallow_filtered, filtered_pagination} = case authorization_module.filter_can(unfiltered, subject, :show) do
      ^unfiltered ->
        {unfiltered, pagination}
      filtered_can ->
        {filtered_can, pagination}
    end

    deep_filtered = authorization_module.filter_associations_can(shallow_filtered, subject, :show)

    {deep_filtered, filtered_pagination}
  end

  @spec can(t, Authorization.action, Authorizaton.target) :: :ok | {:error, :unauthorized}
  defp can(%__MODULE__{authorization_module: authorization_module, subject: subject}, action, target)
       when action in @actions and
            not is_nil(authorization_module) and
            (is_atom(target) or is_map(target) or is_list(target)) do
    if authorization_module.can?(subject, action, target) do
      :ok
    else
      {:error, :unauthorized}
    end
  end

  @spec changeset(t, insertable_params) :: {:ok, Ecto.Changeset.t} | {:error, Ecto.Changeset.t}
  defp changeset(%__MODULE__{resources_module: resources_module},
                 insertable_params)
       when not is_nil(resources_module) and is_atom(resources_module) and
            is_map(insertable_params) do
    insertable_params
    |> resources_module.changeset()
    |> status_changeset()
  end

  @spec changeset(t, Ecto.Schema.t, insertable_params) :: {:ok, Ecto.Changeset.t} | {:error, Ecto.Changeset.t}
  defp changeset(%__MODULE__{resources_module: resources_module}, updatable, updatable_params) do
    updatable
    |> resources_module.changeset(updatable_params)
    |> status_changeset()
  end

  @spec create_changeset(t, Ecto.Changeset.t, params) :: {:ok, struct} | {:error, Document.t} | {:error, Ecto.Changeset.t}
  defp create_changeset(state = %__MODULE__{resources_module: resources_module}, changeset = %Ecto.Changeset{}, params)
      when not is_nil(resources_module) and is_atom(resources_module) do
    with {:ok, query_options} <- params_to_query_options(state, params),
         :ok <- allow_sandbox_access(state, params) do
      resources_module.insert(changeset, query_options)
    end
  end

  @spec delete_ecto_schema(t, Ecto.Schema.t) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  defp delete_ecto_schema(%__MODULE__{resources_module: resources_module}, schema), do: resources_module.delete(schema)

  @spec document(params, FromJson.action) :: {:ok, Document.t}  | {:error, Document.t}
  defp document(raw_params, action) do
    Document.from_json(
      raw_params,
      %Alembic.Error{
        meta: %{
          "action" => action,
          "sender" => :client
        },
        source: %Source{
          pointer: ""
        }
      }
    )
  end

  @spec get(t, params) :: {:error, {:not_found, parameter}} | {:error, Document.t} | {:ok, Ecto.Schema.t}
  defp get(state = %__MODULE__{resources_module: resources_module}, params) do
    with {:ok, query_options} <- params_to_query_options(state, params) do
      get(resources_module, params, "id", query_options)
    end
  end

  @spec get(module, params, id_key :: String.t, Resources.query_options) ::
        {:error, {:not_found, parameter}} | {:ok, Ecto.Schema.t}
  defp get(resources_module, params, id_key, query_options) when is_map(query_options) do
    params
    |> Map.fetch!(id_key)
    |> resources_module.get(query_options)
    |>
    case do
      nil ->
        {:error, {:not_found, id_key}}
      resource ->
        {:ok, resource}
    end
  end

  @spec get_maybe_authorized_related(t, Ecto.Schema.t, atom) ::
        {:error, :unauthorized} | {:ok, nil} | {:ok, Ecto.Schema.t} | no_return
  defp get_maybe_authorized_related(state, source, association) do
    case get_related(source, association) do
      nil ->
        {:ok, nil}
      related ->
        with :ok <- can(state, :show, [related, source]) do
          {:ok, authorized(state, related)}
        end
    end
  end

  # Gets related as long as association is correct
  @spec get_related(Ecto.Schema.t, atom) :: [Ecto.Schema.t] | Ecto.Schema.t | nil
  defp get_related(source, association) do
    case Map.fetch(source, association) do
      :error ->
        raise ArgumentError, "%#{source.__struct__}{} does not have #{inspect association} associaton"
      {:ok, related} ->
        related
    end
  end

  @spec get_source(t,
                   params,
                   %{
                     required(:association) => association,
                     required(:id_key) => atom,
                   }) :: {:error, {:not_found, parameter}} | {:ok, Ecto.Schema.t}
  defp get_source(%{resources_module: resources_module},
                  params,
                  %{association: association, id_key: id_key}) do
    get(resources_module, params, id_key, %{associations: [association]})
  end

  @spec insertable_params(t, Document.t) :: insertable_params
  defp insertable_params(%__MODULE__{ecto_schema_module: ecto_schema_module}, document) do
    document
    |> Document.to_params
    |> ToParams.nested_to_foreign_keys(ecto_schema_module)
  end

  @spec list(t, params) :: {:error, Document.t} | {:ok, [struct], Resources.pagination}
  defp list(state = %__MODULE__{resources_module: resources_module}, params) do
    with {:ok, query_options} <- params_to_query_options(state, params),
         {list, pagination} <- resources_module.list(query_options) do
      {:ok, list, pagination}
    end
  end

  defp params_to_associations_query_option(%__MODULE__{associations_by_include: associations_by_include}, params) do
    fetch = Fetch.from_params(params)

    Includes.to_preloads(fetch.includes, associations_by_include)
  end

  @spec params_to_query_options(t, params) :: {:ok, Resources.query_options} | {:error, Document.t}
  defp params_to_query_options(state = %__MODULE__{}, params) when is_map(params) do
    with {:ok, associations} <- params_to_associations_query_option(state, params) do
      {:ok, %{associations: associations}}
    end
  end

  @spec related_property(t, params, map) ::
        {:error, {:not_found, parameter}} | {:error, :unauthorized} | {:ok, rendered}
  defp related_property(
        state = %__MODULE__{subject: subject, view_module: view_module},
        params,
        %{
          related: related_option,
          source: source_option = %{
            association: association
          }
        }
      ) do
    with {:ok, source} <- get_source(state, params, source_option),
         :ok <- can(state, :show, source),
         {:ok, authorized_related} <- get_maybe_authorized_related(state, source, association) do
      {
        :ok,
        view_related_property(
          state,
          %{
            params: params,
            related: Map.put(related_option, :resource, authorized_related),
            source: Map.merge(
              source_option,
              %{resource: source, view_module: view_module}
            ),
            subject: subject
          }
        )
      }
    end
  end

  defp status_changeset(changeset) do
    status = if changeset.valid? do
               :ok
             else
               :error
             end

    {status, changeset}
  end

  @spec update_changeset(t, Ecto.Changeset.t, params) :: {:ok, Ecto.Schema.t} |
                                                         {:error, Document.t} |
                                                         {:error, Ecto.Changeset.t}
  defp update_changeset(state = %__MODULE__{resources_module: resources_module},
                        changeset = %Ecto.Changeset{},
                        params) do
    with {:ok, query_options} <- params_to_query_options(state, params) do
      resources_module.update(changeset, query_options)
    end
  end

  defp view_related_property(
         %__MODULE__{subject: subject, view_module: view_module},
         %{
           params: params,
           related: related = %{
             property: property,
             resource: resource
           },
           source: source
         }
       ) do
    function_name = case property do
      :relationship -> :show_relationship
      :resource -> :get_related_resource
    end

    apply(
      view_module,
      function_name,
      [
        resource,
        %{
          params: params,
          related: related,
          source: put_in(source.view_module, view_module),
          subject: subject
        }
      ]
    )
  end
end
