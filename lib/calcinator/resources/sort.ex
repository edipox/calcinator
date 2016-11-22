defmodule Calcinator.Resources.Sort do
  @moduledoc """
  Sort in `Calcinator.Resources.query_options`
  """

  alias Alembic.{Document, Error, Fetch.Includes, Source}
  alias Calcinator.Resources

  # Struct

  defstruct field: nil,
            direction: :ascending,
            association: nil

  # Types

  @typedoc """
  Keyword list of association path used to Ecto preloading
  """
  @type association :: Keyword.t

  @typedoc """
  The direction to sort.  Default to `:ascending` per the JSONAPI spec.  Can be `:descending` when the dot-separated
  attribute path is prefixed with `-`.
  """
  @type direction :: :ascending | :descending

  @typedoc """
  Name of a field in an `Ecto.Schema.t`
  """
  @type field_name :: atom

  @typedoc """
  * `:assocation` - Keyword list of nested associations.  `nil` when the `:field` is direction on the primary data.
  * `:direction` - the direction to sort `:field`
  * `:field` - name of the field to sort
  """
  @type t :: %__MODULE__{
               association: nil | association,
               direction: direction,
               field: field_name,
             }

  @typedoc """
  Used to convert includes used by JSONAPI to the corresponding association in Ecto.

  This map does not need to be a simple conversion of the nested map of strings `Alembic.Fetch.Includes.t` to
  the `Keyword.t` of `associations`, but can include completely different names or associations that the JSONAPI doesn't
  even expose, so that deprecated relationships can be mapped to newer associations.
  """
  @type associations_by_include :: %{Alembic.Fetch.Includes.t => association}

  @typedoc """
  * `:associations_by_include` - maps the `Alembic.Fetch.Includes.t` to Keyword.t of associations.
  * `:ecto_schema_module` - primary Ecto.Schema module for checking if attribute is an existent field after applying
    associations.
  """
  @type from_alembic_fetch_sort_options :: %{
                                             required(:associations_by_include) => associations_by_include,
                                             required(:ecto_schema_module) => module
                                           }

  @typedoc """
  Used to convert associations used in Ecto to JSONAPI includes.

  This map need not be the inverse of `associations_by_include` if the JSONAPI incoming relationships are no the same
  as the outgoing relationships.
  """
  @type include_by_associations :: %{association => Alembic.Fetch.Includes.t}

  # Functions

  @doc """
  Maps `Alembic.Fetch.Sort.t` `attribute` to `t` `field` and `Alembic.Fetch.Sort.t` `relationships` to
  `t` `associations`.
  """
  @spec from_alembic_fetch_sort(Alembic.Fetch.Sort.t, from_alembic_fetch_sort_options) ::
        {:ok, t} | {:error, Document.t}
  def from_alembic_fetch_sort(
        sort = %Alembic.Fetch.Sort{direction: direction, relationship: relationship},
        %{
          associations_by_include: associations_by_include,
          ecto_schema_module: ecto_schema_module
        }
      ) do
    with {:ok, association} <- association(relationship, associations_by_include),
         {:ok, field} <- field(sort, ecto_schema_module) do
      {:ok, %__MODULE__{association: association, direction: direction, field: field}}
    end
  end

  @doc """
  Maps `t` `field` to `Alembic.Fetch.Sort.t` `attribute` and `t` `associations` to `Alembic.Fetch.Sort.t`
  `relationships`.
  """
  @spec to_alembic_fetch_sort(t, Resources.t) :: {:ok, Alembic.Fetch.Sort.t} | {:error, Document.t}
  def to_alembic_fetch_sort(%__MODULE__{association: association, direction: direction, field: field}, module) do
    {
      :ok,
      %Alembic.Fetch.Sort{
        attribute: attribute(field),
        direction: direction,
        relationship: relationship(module, association)
      }
    }
  end

  ## Private Functions

  defp association(nil, _), do: {:ok, nil}
  defp association(relationship, associations_by_include) do
    Includes.to_preloads(relationship, associations_by_include)
  end

  defp attribute(field) do
    field
    |> to_string()
    |> String.replace("_", "-")
  end

  defp attribute_error(%Alembic.Fetch.Sort{attribute: attribute, relationship: relationship}) do
    relationship_path = Includes.to_string([relationship])

    %Error{
      detail: "`#{relationship_path}` does not have a `#{attribute}` attribute",
      meta: %{
        "attribute" => attribute,
        "relationship_path" => relationship_path
      },
      source: %Source{
        parameter: "sort"
      },
      title: "Unknown attribute"
    }
  end

  defp attribute_error_document(sort), do: %Document{errors: [attribute_error(sort)]}

  defp attribute_error_result(sort), do: {:error, attribute_error_document(sort)}

  defp field(sort = %Alembic.Fetch.Sort{relationship: relationship}, ecto_schema_module) do
    field(sort, ecto_schema_module, relationship)
  end

  defp field(sort = %Alembic.Fetch.Sort{attribute: attribute}, ecto_schema_module, nil) do
    field_string = String.replace(attribute, "-", "_")

    try do
      String.to_existing_atom(field_string)
    rescue
      ArgumentError ->
        attribute_error_result(sort)
    else
      field ->
        if field in ecto_schema_module.__schema__(:fields) do
          {:ok, field}
        else
          attribute_error_result(sort)
        end
    end
  end

  defp relationship(_, nil), do: nil
  defp relationship(module, association), do: module.association_to_include(association)
end
