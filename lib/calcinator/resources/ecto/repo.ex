defmodule Calcinator.Resources.Ecto.Repo do
  @moduledoc """
  Default callbacks for `Calcinator.Resources` behaviour when backed by a single `Ecto.Repo`
  """

  alias Ecto.{Adapters.SQL.Sandbox, Query}

  require Logger
  require Query

  import Ecto.Changeset, only: [cast: 3]

  # Types

  @typedoc """
  Name of a module that defines an `Ecto.Schema.t`
  """
  @type ecto_schema_module :: module

  # Callbacks

  @doc """
  The `Ecto.Schema` module stored in `repo/0`.
  """
  @callback ecto_schema_module() :: module

  @doc """
  The full list of associations to preload in

    * `Calcinator.Resources.get/2`
    * `Calcinator.Resources.insert/2`
    * `Calcinator.Resources.list/1`
    * `Calcinator.Resources.update/2`
    * `Calcinator.Resources.update/3`

  Should combine the request-specific associations in `Resources.query_options` with any default associations and/or
  transform requested associations to `repo/0`-specific associations.
  """
  @callback full_associations(Resources.query_options) :: [atom] | Keyword.t

  @doc """
  The `Ecto.Repo` that stores `ecto_schema_module/0`.
  """
  @callback repo() :: module

  # Macros

  defmacro __using__([]) do
    quote do
      alias Calcinator.Resources.Ecto.Repo, as: EctoRepoResources

      # Behaviours

      @behaviour Calcinator.Resources
      @behaviour EctoRepoResources

      # Functions

      def full_associations(query_options = %{}), do: EctoRepoResources.full_associations(query_options)

      ## Resources callbacks

      @spec allow_sandbox_access(Resources.sandbox_access_token) :: :ok | {:already, :owner | :allowed} | :not_found
      def allow_sandbox_access(token), do: EctoRepoResources.allow_sandbox_access(token)

      def changeset(params), do: EctoRepoResources.changeset(__MODULE__, params)

      def changeset(data, params), do: EctoRepoResources.changeset(__MODULE__, data, params)

      def delete(data), do: EctoRepoResources.delete(__MODULE__, data)

      @spec get(Resources.id, Resources.query_options) :: {:ok, Ecto.Schema.t} | {:error, :not_found}
      def get(id, opts), do: EctoRepoResources.get(__MODULE__, id, opts)

      def insert(changeset_or_params, query_options) do
        EctoRepoResources.insert(__MODULE__, changeset_or_params, query_options)
      end

      @spec list(Resources.query_options) :: {:ok, [Ecto.Schema.t], nil}
      def list(query_options), do: EctoRepoResources.list(__MODULE__, query_options)

      def sandboxed?(), do: EctoRepoResources.sandboxed?(__MODULE__)

      def update(changeset, query_options), do: EctoRepoResources.update(__MODULE__, changeset, query_options)

      def update(data, params, query_options), do: EctoRepoResources.update(__MODULE__, data, params, query_options)

      defoverridable [
                       allow_sandbox_access: 1,
                       changeset: 1,
                       changeset: 2,
                       delete: 1,
                       full_associations: 1,
                       get: 2,
                       insert: 2,
                       list: 1,
                       sandboxed?: 0,
                       update: 2,
                       update: 3
                     ]
    end
  end

  # Functions

  @doc """
  Allows access to `Ecto.Adapters.SQL.Sandbox`
  """
  @spec allow_sandbox_access(Resources.sandbox_access_token) :: :ok | {:already, :owner | :allowed} | :not_found
  def allow_sandbox_access(%{owner: owner, repo: repo}) do
    repo
    |> List.wrap()
    |> Enum.each(&Sandbox.allow(&1, owner, self))
  end

  @doc """
  `Ecto.Changeset.t` using the default `Ecto.Schema.t` for `module` with `params`
  """
  @spec changeset(module, Resources.params) :: Ecto.Changeset.t
  def changeset(module, params), do: module.changeset(module.ecto_schema_module.__struct__, params)

  @doc """
  1. Casts `params` into `data` using `optional_field/0` and `required_fields/0` of `module`
  2. Validates changeset with `module` `ecto_schema_module/0` `changeset/0`
  """
  def changeset(module, data, params) do
    ecto_schema_module = module.ecto_schema_module()

    data
    |> cast(params, ecto_schema_module.optional_fields() ++ ecto_schema_module.required_fields())
    |> ecto_schema_module.changeset()
  end

  @doc """
  Deletes `data` from `module`'s `repo/0`
  """
  def delete(module, data), do: module.repo().delete(data)

  @doc """
  Uses `query_options` as full associatons with no additions.
  """
  def full_associations(query_options), do: Map.get(query_options, :associations, [])

  @doc """
  Gets resource with `id` from `module` `repo/0`.

  ## Returns

    * `{:error, :not_found}` - if `id` is not found in `module`'s `repo/0`.
    * `{:error, :ownership}` - if `DBConnection.OwnershipError` due to connection sharing error during tests.
    * `{:ok, struct}` - if `id` is found in `module`'s `repo/0`.  Associations will also be preloaded in `struct` based
      on `Resources.query_options`.

  """
  @spec get(module, Resources.id, Resources.query_options) ::
        {:ok, Ecto.Schema.t} | {:error, :not_found} | {:error, :ownership}
  def get(module, id, opts) do
    ecto_schema_module = module.ecto_schema_module()
    repo = module.repo()

    try do
      repo.get(ecto_schema_module, id)
    rescue
      ownership_error in DBConnection.OwnershipError ->
        ownership_error
        |> inspect()
        |> Logger.error()

        {:error, :ownership}
    else
      nil ->
        {:error, :not_found}
      data ->
        {:ok, preload(module, data, opts)}
    end
  end

  @doc """
  Insert `changeset` into `module` `repo/0`

  ## Returns

    * `{:error, Ecto.Changeset.t}` - if `changeset` cannot be inserted into `module` `repo/0`
    * `{:ok, struct}` - if `changeset` was inserted in to `module` `repo/0`.  `struct` is preloaded with associations
      according to `Resource.query_iptions` in `opts`.

  """
  def insert(module, changeset = %Ecto.Changeset{}, opts) when is_map(opts) do
    with {:ok, inserted} <- module.repo().insert(changeset) do
      {:ok, preload(module, inserted, opts)}
    end
  end

  @doc """
  Inserts `params` into `module` `repo/0` after converting them into an `Ecto.Changeset.t`

  ## Returns

    * `{:error, Ecto.Changeset.t}` - if changeset cannot be inserted into `module` `repo/0`
    * `{:ok, struct}` - if changeset was inserted in to `module` `repo/0`.  `struct` is preloaded with associations
      according to `Resource.query_iptions` in `opts`.

  """
  def insert(module, params, opts) when is_map(params) and is_map(opts) do
    params
    |> module.changeset()
    |> module.insert(opts)
  end

  @doc """

  ## Returns

    * `{:error, :ownership}` - if `DBConnection.OwnershipError` due to connection sharing error during tests.
    * `{:ok, [struct], nil}` - `[struct]` is the list of all `module` `ecto_schema_module/0` in `module` `repo/0`.
      There is no (current) support for pagination: pagination is the `nil` in the 3rd element of the tuple.

  """
  @spec list(module, Resources.query_options) :: {:ok, [Ecto.Schema.t], nil}
  def list(module, opts) do
    repo = module.repo()
    query = preload(module, module.ecto_schema_module(), opts)

    try do
      repo.all(query)
    rescue
      ownership_error in DBConnection.OwnershipError ->
        ownership_error
        |> inspect()
        |> Logger.error()
        {:error, :ownership}
    else
      all ->
        {:ok, all, nil}
    end
  end

  @doc """
  Whether `module` `repo/0` is sandboxed and `allow_sandbox_access/1` should be called.
  """
  def sandboxed?(module) do
    module.repo().sandboxed?()
  end

  @doc """
  Updates `struct` in `module` `repo/0` using `changeset`.

  ## Returns

    * `{:error, Ecto.Changeset.t}` - if the `changeset` had validations error or it could not be used to update `struct`
      in `module` `repo/0`.
    * `{:ok, struct}` - the updated `struct`.  Associations are preloaded using `Resources.query_options` in
      `query_options`.

  """
  @spec update(module, Ecto.Changeset.t, Resources.query_options) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def update(module, changeset, query_options) do
    with {:ok, updated} <- module.repo().update(changeset) do
      {:ok, update_preload(module, updated, query_options)}
    end
  end

  @doc """
  Updates `data` with `params` in `module` `repo/0`

  ## Returns

    * `{:error, Ecto.Changeset.t}` - if the changeset derived from updating `data` with `params` had validations error
      or it could not be used to update `data` in `module` `repo/0`.
    * `{:ok, struct}` - the updated `struct`.  Associations are preloaded using `Resources.query_options` in
      `query_options`.

  """
  @spec update(module, Ecto.Schema.t, Resources.params, Resources.query_options) ::
          {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}
  def update(module, data, params, query_options) do
    data
    |> module.changeset(params)
    |> module.update(query_options)
  end

  ## Private Functions

  defp preload(module, data_or_queryable, query_options) do
    ecto_schema_module = module.ecto_schema_module()

    case data_or_queryable do
      data = %{__struct__: ^ecto_schema_module} ->
        module.repo().preload(data, module.full_associations(query_options))
      queryable ->
        Query.preload(queryable, ^module.full_associations(query_options))
    end
  end

  defp update_preload(module, updated, query_options) do
    preloads = module.full_associations(query_options)
    repo = module.repo()

    # have to unload preloads that may have been updated
    # See http://stackoverflow.com/a/34946099/470451
    # See https://github.com/elixir-lang/ecto/issues/1212
    preloads
    |> Enum.reduce(updated, fn
         # preloads = [:<field>]
         (field, acc) when is_atom(field) ->
           Map.put(acc, field, Map.get(acc.__struct__.__struct__, field))
         # preloads = [<field>: <association_preloads>]
         ({field, _}, acc) when is_atom(field) ->
           Map.put(acc, field, Map.get(acc.__struct__.__struct__, field))
       end)
    |> repo.preload(preloads)
  end
end
