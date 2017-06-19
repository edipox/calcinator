defmodule Calcinator.Resources.Page do
  @moduledoc """
  DEPRECATED: use `Alembic.Pagination.Page` instead.
  """

  alias Alembic.{Document, Error, FromJson, Source}

  # Constants
  @error_template %Alembic.Error{
    source: %Alembic.Source{
      pointer: "/page"
    }
  }

  @number_options %{
    field: :number,
    member: %{
      from_json: &__MODULE__.positive_integer_from_json/2,
      name: "number",
      required: true
    }
  }

  @size_options %{
    field: :size,
    member: %{
      from_json: &__MODULE__.positive_integer_from_json/2,
      name: "size",
      required: true
    }
  }

  @page_child_options_list [
    @number_options,
    @size_options
  ]

  # Struct

  defstruct ~w(number size)a

  # Types

  @typedoc """
    * `number` - the page number.  1-based.
    * `size` - the size of each page.
  """
  @type t :: %__MODULE__{
               number: pos_integer,
               size: pos_integer
             }

  # Functions

  @doc false
  def from_params(params) do
    IO.warn "`Calcinator.Resources.Page.from_params/1` is deprecated; " <>
            "use `Alembic.Pagination.Page.t` instead of `Calcinator.Resources.Page.t` and " <>
            "call `Alembic.Pagination.Page.from_params/1` instead."

    deprecated_from_params(params)
  end

  @doc false
  def to_params(maybe_page) do
    IO.warn "`Calcinator.Resources.Page.to_params/1` is deprecated; " <>
            "use `Alembic.Pagination.Page.t` instead of `Calcinator.Resources.Page.t` and " <>
            "call `Alembic.Pagination.Page.to_params/1` instead."

    deprecated_to_params(maybe_page)
  end

  @doc false
  def positive_integer_from_json(child, error_template) do
    with {:ok, integer} <- integer_from_json(child, error_template) do
      integer_to_positive_integer(integer, error_template)
    end
  end

  ## Private Functions

  defp deprecated_from_params(%{"page" => page}) when is_map(page) do
    parent = %{
      error_template: @error_template,
      json: page
    }

    @page_child_options_list
    |> Stream.map(&Map.put(&1, :parent, parent))
    |> Stream.map(&FromJson.from_parent_json_to_field_result/1)
    |> FromJson.reduce({:ok, %__MODULE__{}})
  end

  defp deprecated_from_params(%{"page" => page}) when not is_map(page) do
    {:error, %Document{errors: [Error.type(@error_template, "object")]}}
  end

  defp deprecated_from_params(params) when is_map(params), do: {:ok, nil}

  defp deprecated_to_params(nil), do: %{}

  defp deprecated_to_params(%__MODULE__{number: number, size: size})
      when is_integer(number) and number > 0 and
           is_integer(size) and size > 0 do
    %{
      "page" => %{
        "number" => number,
        "size" => size
      }
    }
  end

  defp integer_from_json(
         quoted_integer,
         error_template = %Error{
           source: source = %Source{
             pointer: pointer
           }
         }
       ) when is_binary(quoted_integer) do
    case Integer.parse(quoted_integer) do
      :error ->
        {
          :error,
          %Document{
            errors: [
              Error.type(error_template, "quoted integer")
            ]
          }
        }
      {integer, ""} ->
        {:ok, integer}
      {integer, remainder_of_binary} ->
        {
          :error,
          %Document{
            errors: [
              %Error{
                detail: "`#{pointer}` contains quoted integer (`#{integer}`), " <>
                        "but also excess text (`#{inspect remainder_of_binary}`)",
                meta: %{
                  excess: remainder_of_binary,
                  integer: integer,
                  type: "quoted integer",
                },
                source: source,
                status: "422",
                title: "Excess text in quoted integer"
              }
            ]
          }
        }
    end
  end

  defp integer_from_json(integer, _) when is_integer(integer), do: {:ok, integer}

  defp integer_from_json(_, error_template) do
    {
      :error,
      %Document{
        errors: [
          Error.type(error_template, "integer")
        ]
      }
    }
  end

  defp integer_to_positive_integer(integer, _) when is_integer(integer) and integer > 0 do
    {:ok, integer}
  end

  defp integer_to_positive_integer(integer, error_template) when is_integer(integer) do
    {:error, %Document{errors: [Error.type(error_template, "positive integer")]}}
  end
end
