defmodule Calcinator.Resources do
  @moduledoc """
  A module that exposes Ecto schema structs
  """

  alias Alembic.{Document, Error, Source}
  alias Resources.Page

  # Types

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
    optional(:filters) => %{String.t => String.t},
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
  @callback changeset(resource :: Ecto.Schema.t, params) :: Ecto.Changeset.t

  @doc """
  Deletes a single `struct`

  # Returns

    * `{:ok, struct}` - the delete succeeded and the returned struct is the state before delete
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, Ecto.Changeset.t}` - errors while deleting the `struct`.  `Ecto.Changeset.t` `errors` contains errors.
  """
  @callback delete(struct) :: {:ok, struct} | {:error, :ownership} | {:error, Ecto.Changeset.t}

  @doc """
  Gets a single `struct`

  # Returns

    * `{:ok, struct}` - `id` was found.
    * `{:error, :not_found}` - `id` was not found.
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :timeout}` - timeout occured while getting `id` from backing store .
    * `{:error, reason}` - an error occurred with the backing store for `reason` that is backing store specific.

  """
  @callback get(id, query_options) ::
            {:ok, struct} | {:error, :not_found} | {:error, :ownership} | {:error, :timeout} | {:error, reason :: term}

  @doc """
  Inserts `changeset` into a single new `struct`

  # Returns
    * `{:ok, struct}` - `changeset` was inserted into `struct`
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, Ecto.Changeset.t}` - insert failed.  `Ecto.Changeset.t` `errors` contain errors.
  """
  @callback insert(Ecto.Changeset.t, query_options) :: {:ok, struct} | {:error, :ownership} | {:error, Ecto.Changeset.t}

  @doc """
  Inserts `params` into a single new `struct`

  # Returns

    * `{:ok, struct}` - params were inserted into `struct`
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, Ecto.Changeset.t}` - insert failed.  `Ecto.Changeset.t` `errors` contain errors.

  """
  @callback insert(params, query_options) :: {:ok, struct} | {:error, :ownership} | {:error, Ecto.Changeset.t}

  @doc """
  Gets a list of `struct`s.

  # Returns

    * `{:ok, [resource], nil}` - all resources matching query
    * `{:ok, [resource], pagination}` - page of resources matching query
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :timeout}` - timeout occured while getting resources from backing store .
    * `{:error, reason}` - an error occurred with the backing store for `reason` that is backing store specific.

  """
  @callback list(query_options) :: {:ok, [struct], pagination | nil} |
                                   {:error, :ownership} |
                                   {:error, :timeout} |
                                   {:error, reason :: term}

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
    * `{:error, Ecto.Changeset.t}` - errors while updating `struct` with `params`.  `Ecto.Changeset.t` `errors` contains
      errors.
    * `{:error, :bad_gateway}` - error in backing store that cannot be represented as another type of error
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, :not_found}` - the resource in the changeset was not found and so cannot be updated.  This may mean that
      the resource was deleted with `delete/1` after the `get/2` or `list/1` returned.
  """
  @callback update(resource :: Ecto.Schema.t, params, query_options) :: {:ok, struct} |
                                                                        {:error, Ecto.Changeset.t} |
                                                                        {:error, :bad_gateway} |
                                                                        {:error, :ownership} |
                                                                        {:error, :not_found}

  @doc """
  Applies updates in `changeset`

  # Returns

    * `{:ok, struct}` - the update succeeded and the returned `struct` contains the updates
    * `{:error, :ownership}` - connection to backing store was not owned by the calling process
    * `{:error, Ecto.Changeset.t}` - errors while updating `struct` with `params`.  `Ecto.Changeset.t` `errors` contains
      errors.
  """
  @callback update(Ecto.Changeset.t, query_options) :: {:ok, struct} | {:error, :ownership} | {:error, Ecto.Changeset.t}

  # Functions

  @doc """
  Converts the attribute to a field if a corresponding field exists in `ecto_schema_module`

  If a field exists, then it is returned.  This includes fields with `_` that have `-` in their attribute name and
  virtual fields.

      iex> Calcinator.Resources.attribute_to_field("name", Calcinator.Resources.TestAuthor)
      {:ok, :name}
      iex> Calcinator.Resources.attribute_to_field("password-confirmation", Calcinator.Resources.TestAuthor)
      {:ok, :password_confirmation}

  Invalid field names will return an error

      iex> Calcinator.Resources.attribute_to_field("password-hash", Calcinator.Resources.TestAuthor)
      {:error, "password-hash"}

  Associations are not fields, so they will return an error

      iex> Calcinator.Resources.attribute_to_field("author", Calcinator.Resources.TestPost)
      {:error, "author"}

  ## Returns

    * `{:ok, field}` - `attribute` with `-` has the corresponding `field` with `_` in `ecto_schema_module`
    * `{:error, attribute}` - `attribute` does not have corresponding field in `ecto_schema_module`

  """
  def attribute_to_field(attribute, ecto_schema_module) when is_binary(attribute) and is_atom(ecto_schema_module) do
    field_string = String.replace(attribute, "-", "_")

    for(potential_field <- fields(ecto_schema_module),
        potential_field_string = to_string(potential_field),
        potential_field_string == field_string, do: potential_field)
    |> case do
      [field] ->
        {:ok, field}
      [] ->
        {:error, attribute}
    end
  end

  @doc """
  Error when a filter `name` is not supported by the callback module.

      iex> Calcinator.Resources.unknown_filter("name")
      %Alembic.Document{
        errors: [
          %Alembic.Error{
            detail: "Unknown name filter",
            source: %Alembic.Source{
              pointer: "/filter/name"
            },
            status: "422",
            title: "Unknown Filter"
          }
        ]
      }

  """
  @spec unknown_filter(name :: String.t) :: Document.t
  def unknown_filter(name) do
    %Document{
      errors: [
        %Error{
          detail: "Unknown #{name} filter",
          title: "Unknown Filter",
          source: %Source{
            pointer: "/filter/#{name}"
          },
          status: "422"
        }
      ]
    }
  end

  ## Private Functions

  # Returns both fields and virtual fields
  defp fields(ecto_schema_module) do
    associations = ecto_schema_module.__schema__(:associations)

    # ecto_schema_module.__schema__(:fields) does not include virtual fields, so
    # deduce real and virtual fields from struct keys
    keys = ecto_schema_module.__struct__ |> Map.keys
    keys -- [:__meta__, :__struct__ | associations]
  end
end
