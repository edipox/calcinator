defmodule Calcinator.Resources.TestPost do
  @moduledoc """
  A schema used in examples in `Calcinator.Resources`
  """

  use Ecto.Schema

  schema "posts" do
    field :body, :string

    timestamps()

    belongs_to :author, Calcinator.Resources.TestAuthor
    has_many :comments, Calcinator.Resources.TestComment
  end
end
