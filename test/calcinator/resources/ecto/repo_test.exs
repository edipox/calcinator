defmodule Calcinator.Resources.Ecto.RepoTest do
  alias Alembic.{Document, Error, Source}
  alias Calcinator.Resources.Ecto.Repo.{Factory, TestAuthors, TestComments}

  use ExUnit.Case, async: true

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Calcinator.Resources.Ecto.Repo.Repo)

    :ok
  end

  describe "list/2" do
    test "valid filter filters the list" do
      [first_author, second_author, third_author] = Factory.insert_list(3, :test_author)

      assert {:ok, list_authors, nil} = TestAuthors.list(%{filters: %{"id" => "1,3"}})

      assert length(list_authors) == 2

      list_author_ids = Enum.map(list_authors, &(&1.id))

      assert first_author.id in list_author_ids
      refute second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end

    test "multiple invalid filters return error for each invalid filter" do
      assert {:error, %Document{errors: errors}} = TestAuthors.list(
               %{
                 filters: %{
                   "first_invalid_filter" => "true",
                   "id" => "1,2",
                   "second_invalid_filter" => "false"
                 }
               }
             )
      assert length(errors) == 2
      assert %Error{
               detail: "Unknown second_invalid_filter filter",
               source: %Source{
                 pointer: "/filter/second_invalid_filter"
               },
               status: "422",
               title: "Unknown Filter"
             } in errors
      assert %Error{
               detail: "Unknown first_invalid_filter filter",
               source: %Source{
                 pointer: "/filter/first_invalid_filter"
               },
               status: "422",
               title: "Unknown Filter"
             } in errors
    end

    test "with no filter/3 callback, returns error(s)" do
      assert {:error, %Document{errors: errors}} = TestComments.list(%{filters: %{"spam" => "true", "text" => "spam"}})
      assert length(errors) == 2
    end
  end
end
