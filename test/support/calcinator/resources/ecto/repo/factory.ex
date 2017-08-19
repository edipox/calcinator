defmodule Calcinator.Resources.Ecto.Repo.Factory do
  @moduledoc """
  Factories for test schemas.
  """

  alias Calcinator.Resources.{Ecto.Repo.Repo, TestAuthor, TestPost, TestTag}

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

  def test_tag_factory do
    %TestTag{
      name: sequence(:test_post_name, &"tag#{&1}")
    }
  end
end
