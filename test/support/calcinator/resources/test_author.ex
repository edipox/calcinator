defmodule Calcinator.Resources.TestAuthor do
  @moduledoc """
  A schema used in examples in `Calcinator.Resources`
  """

  use Ecto.Schema

  schema "authors" do
    field :name, :string

    has_many :posts, Calcinator.Resources.TestPost, foreign_key: :author_id
  end
end
