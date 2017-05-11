defmodule Calcinator.Resources.Ecto.Repo.Factory do
  @moduledoc """
  Factories for test schemas.
  """

  alias Calcinator.Resources.{Ecto.Repo.Repo, TestAuthor, TestPost}

  use ExMachina.Ecto, repo: Repo

  @dialyzer {:no_return, create: 1, create: 2, create_list: 3, create_pair: 2, fields_for: 1}

  def test_author_factory do
    %TestAuthor{
      name: Faker.Name.name()
    }
  end

  def test_post_factory do
    %TestPost{
      author: build(:test_author),
      body: Faker.Lorem.sentence()
    }
  end
end
