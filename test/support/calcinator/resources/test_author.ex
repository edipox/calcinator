defmodule Calcinator.Resources.TestAuthor do
  @moduledoc """
  A schema used in examples in `Calcinator.Resources`
  """

  use Ecto.Schema

  schema "authors" do
    field :name, :string
    field :password, :string, virtual: true
    field :password_confirmation, :string, virtual: true

    has_many :posts, Calcinator.Resources.TestPost, foreign_key: :author_id
  end
end
