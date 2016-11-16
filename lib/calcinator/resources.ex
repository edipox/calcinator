defmodule Calcinator.Resources do
  @moduledoc """
  A module that exposes Ecto schema structs
  """

  alias Resources.Page

  # Types

  @typedoc """
  Invoke `name` filter with `value`.
  """
  @type filter :: %{name :: String.t => value :: term}

  @typedoc """
  ID that uniquely identifies the `struct`
  """
  @type id :: term

  @typedoc """
  Pagination information returned from the backing store.
  """
  @type pagination :: map

  @type params :: map

  @typedoc """
    * `:associations` - associations to load in the `struct`
    * `:filters` - filters on the result
    * `:page` - the page used for pagination.  `nil` implies no pagination, not default pagination.
    * `:sorts` - the directions to sort fields on the primary resource or its associations
  """
  @type query_options :: %{
    optional(:associations) => atom | [atom],
    optional(:filters) => [filter],
    optional(:page) => Page.t | nil,
    optional(:sorts) => Sorts.t
  }

  @type sandbox_access_token :: %{required(:owner) => term, optional(atom) => any}

  @typedoc """
  A module that implements the `Resources` behaviour
  """
  @type t :: module

  # Callbacks

  @doc """
  Allows access to sandbox for testing
  """
  @callback allow_sandbox_access(sandbox_access_token) :: :ok | {:already, :owner | :allowed} | :not_found

  @doc """
  Changeset for creating a struct from the `params`
  """
  @callback changeset(params) :: Ecto.Changeset.t

  @doc """
  Changeset for updating `struct` with `params`
  """
  @callback changeset(Ecto.Schema.t, params) :: Ecto.Changeset.t

  @doc """
  Deletes a single `struct`

  # Returns

    * `{:ok, struct}` - the delete succeeded and the returned struct is the state before delete
    * `{:error, Ecto.Changeset.t}` - errors while deleting the `struct`.  `Ecto.Changeset.t` `errors` contains errors.
  """
  @callback delete(struct) :: {:ok, Ecto.Schema.t} | {:error, Ecto.Changeset.t}

  @doc """
  Gets a single `struct`

  # Returns

    * `{:ok, struct}` - `id` was found.
    * `{:error, :not_found}` - `id` was not found.
    * `{:error, :timeout}` - timeout occured while getting `id` from backing store .
    * `{:error, reason}` - an error occurred with the backing store for `reason` that is backing store specific.

  """
  @callback get(id, query_options) ::
            {:ok, Ecto.Schema.t} | {:error, :not_found} | {:error, :timeout} | {:error, reason :: term}

  @doc """
  Inserts `changeset` into a single new `struct`

  # Returns
    * `{:ok, struct}` - `changeset` was inserted into `struct`
    * `{:error, Ecto.Changeset.t}` - insert failed.  `Ecto.Changeset.t` `errors` contain errors.
  """
  @callback insert(Ecto.Changeset.t, query_options) :: {:ok, struct} | {:error, Ecto.Changeset.t}

  @doc """
  Inserts `params` into a single new `struct`

  # Returns

    * `{:ok, struct}` - params were inserted into `struct`
    * `{:error, Ecto.Changeset.t}` - insert failed.  `Ecto.Changeset.t` `errors` contain errors.

  """
  @callback insert(params, query_options) :: {:ok, struct} | {:error, Ecto.Changeset.t}

  @doc """
  Gets a list of `struct`s.

  # Returns

    * `{:ok, [resource], nil}` - all resources matching query
    * `{:ok, [resource], pagination}` - page of resources matching query
    * `{:error, :timeout}` - timeout occured while getting resources from backing store .
    * `{:error, reason}` - an error occurred with the backing store for `reason` that is backing store specific.

  """
  @callback list(query_options) :: {:ok, [struct], pagination | nil} | {:error, :timeout} | {:error, reason :: term}

  @doc """
  # Returns

    * `true` - if `allow_sandbox_access/1` should be called before any of the query methods are called
    * `false` - otherwise
  """
  @callback sandboxed?() :: boolean

  @doc """
  Updates `struct`

  # Returns

    * `{:ok, struct}` - the update succeeded and the returned `struct` contains the updates
    * `{error, Ecto.Changeset.t}` - errors while updating `struct` with `params`.  `Ecto.Changeset.t` `errors` contains
      errors.
  """
  @callback update(Ecto.Schema.t, params, query_options) :: {:ok, struct} | {:error, Ecto.Changeset.t}

  @doc """
  Applies updates in `changeset`

  # Returns

    * `{:ok, struct}` - the update succeeded and the returned `struct` contains the updates
    * `{error, Ecto.Changeset.t}` - errors while updating `struct` with `params`.  `Ecto.Changeset.t` `errors` contains
      errors.
  """
  @callback update(Ecto.Changeset.t, query_options) :: {:ok, struct} | {:error, Ecto.Changeset.t}
end
