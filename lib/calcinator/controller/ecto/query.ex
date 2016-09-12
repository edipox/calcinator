defmodule Calcinator.Controller.Ecto.Query do
  @moduledoc """
  Query builders for `Calcinator.Controller`
  """

  alias Ecto.Association.BelongsTo
  alias Ecto.Association.Has
  alias Calcinator.Controller
  alias Plug.Conn

  import Ecto.Query

  # Types

  @type params :: map

  # Functions

  @doc """
  Retrieves models related to source with `source_id_key` as its `id`.
  """
  @spec related(Conn.t, params, Controller.Ecto.t) :: Ecto.Queryable.t
  def related(%Conn{
                assigns: %{
                  association: association,
                  source: %{
                    id_key: source_id_key
                  }
                }
              },
              params,
              %Controller.Ecto{ecto_schema: ecto_schema}) do
    ecto_schema
    |> join(:left, [related], source in assoc(related, ^association))
    |> where([_, source], source.id == ^params[source_id_key])
    |> select([related, _], related)
  end

  @spec relationship(Conn.t, params, Controller.Ecto.t) :: Ecto.Queryable.t
  def relationship(%Conn{
                     assigns: %{
                       association: association,
                       owner: %{
                         id_key: owner_id_key
                       }
                     }
                   },
                   params,
                   %Controller.Ecto{ecto_schema: ecto_schema}) do
    case ecto_schema.__schema__(:association, association) do
      %Has{queryable: queryable, related_key: related_key} ->
        where(queryable, [relationship], field(relationship, ^related_key) == ^params[owner_id_key])
    end
  end

  @doc """
  Retrieves the source model to check for authorization before getting {related/3} models.
  """
  @spec source(Conn.t, params, Controller.Ecto.t) :: Ecto.Queryable.t
  def source(%Conn{
               assigns: %{
                 association: association,
                 source: %{
                   id_key: source_id_key
                 }
               }
             },
             params,
             %Controller.Ecto{ecto_schema: ecto_schema}) do
    case ecto_schema.__schema__(:association, association) do
      %BelongsTo{queryable: queryable, related_key: related_key} ->
        where(queryable, [source], field(source, ^related_key) == ^params[source_id_key])
      %Has{queryable: queryable, related: has_related} ->
        [primary_key] = has_related.__schema__(:primary_key)
        where(queryable, [source], field(source, ^primary_key) == ^params[source_id_key])
    end
  end
end
