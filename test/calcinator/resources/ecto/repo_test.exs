defmodule Calcinator.Resources.Ecto.RepoTest do
  alias Alembic.{Document, Error, Pagination, Pagination.Page, Source}
  alias Calcinator.Resources.Ecto.Repo.{Factory, TestAuthors, TestComments, TestPosts}
  alias Calcinator.Resources.Ecto.Repo.Repo

  use ExUnit.Case, async: true

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    :ok
  end

  describe "list/2 with default page size" do
    setup :default_page_size

    test "valid filter filters the list", %{default_page_size: default_page_size} do
      unfiltered_page_count = 6
      posts = Factory.insert_list(default_page_size * unfiltered_page_count, :test_post)

      # 3 pages, so still multipage, but total_size should differ from unpaginated total_size before of filter
      filtered_page_count = div(unfiltered_page_count, 2)
      expected_list_post_count = default_page_size * filtered_page_count

      filtered_posts = Enum.take(posts, expected_list_post_count)
      id_filter_value = Enum.map_join filtered_posts, ",", fn %{id: id} ->
        id
      end

      query_options = %{filters: %{"id" => id_filter_value}}

      assert {
               :ok,
               first_page_posts,
               %Pagination{
                 first: first_page = %Page{number: 1, size: ^default_page_size},
                 last: last_page = %Page{number: 3, size: ^default_page_size},
                 # multipage has next on first
                 next: second_page = %Page{number: 2, size: ^default_page_size},
                 # first page does not have previous
                 previous: nil
               }
             } = TestPosts.list(query_options)
      assert length(first_page_posts) == default_page_size

      assert {
               :ok,
               second_page_posts,
               %Pagination{
                 first: ^first_page,
                 last: ^last_page,
                 # middle page has next
                 next: third_page = ^last_page,
                 # middle page has previous
                 previous: ^first_page
               }
             } = query_options
                 |> Map.put(:page, second_page)
                 |> TestPosts.list()
      assert length(second_page_posts) == default_page_size

      assert {
               :ok,
               third_page_posts,
               %Pagination{
                 first: ^first_page,
                 last: ^last_page,
                 # last page does not have next
                 next: nil,
                 # last page has previous
                 previous: ^second_page
               }
             } = query_options
                 |> Map.put(:page, third_page)
                 |> TestPosts.list()
      assert length(third_page_posts) == default_page_size

      list_post_id_set = Enum.reduce(
        [first_page_posts, second_page_posts, third_page_posts],
        MapSet.new,
        fn page_posts, acc ->
          Enum.into(page_posts, acc, &to_id/1)
        end
      )

      filtered_post_id_set = id_set(filtered_posts)

      assert list_post_id_set == filtered_post_id_set
    end
  end

  describe "list/2 without default page size" do
    test "valid filter filters the list" do
      [first_author, second_author, third_author] = Factory.insert_list(3, :test_author)

      assert {:ok, list_authors, nil} = TestAuthors.list(%{filters: %{"id" => "#{first_author.id},#{third_author.id}"}})

      assert length(list_authors) == 2

      list_author_ids = Enum.map(list_authors, &(&1.id))

      assert first_author.id in list_author_ids
      refute second_author.id in list_author_ids
      assert third_author.id in list_author_ids
    end

    test "filtered queries pass through distinct/2 before returning results" do
      insert! = fn ->
        author = Factory.insert(:test_author)

        # Needs to be > 1 matching posts per body to check distinct is happening
        Factory.insert_list(2, :test_post, author: author, body: "Shared Body")

        author
      end

      [first_author, second_author, third_author] = insert!
                                                    |> Stream.repeatedly()
                                                    |> Enum.take(3)

      assert {:ok, list_authors, nil} =
               TestAuthors.list(
                 %{
                   filters: %{
                     "id" => "#{first_author.id},#{third_author.id}",
                     "posts.body" => "Shared"
                   }
                 }
               )

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

  # Functions

  ## Private Functions

  defp default_page_size(_) do
    default_page_size = 2

    Application.put_env(:calcinator, TestPosts, [default_page_size: default_page_size])

    on_exit fn ->
      Application.delete_env(:calcinator, TestPosts)
    end

    %{default_page_size: default_page_size}
  end

  defp id_set(resources) when is_list(resources), do: Enum.into(resources, MapSet.new(), &to_id/1)

  defp to_id(%{id: id}), do: id
end
