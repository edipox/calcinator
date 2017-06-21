defmodule Calcinator.Resources.Ecto.RepoTest do
  alias Alembic.{Document, Error, Pagination, Pagination.Page, Source}
  alias Calcinator.Resources.Ecto.Repo.{Factory, TestAuthors, TestComments, TestPosts}
  alias Calcinator.Resources.Ecto.Repo.Repo

  use ExUnit.Case, async: true

  setup do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    :ok
  end

  # 111
  describe "list/1 with minimum page size with default page size with maximum page size" do
    setup [:minimum_page_size, :default_page_size, :maximum_page_size]

    test "without page query option returns page with default page size", %{page_size: %{default: default}} do
      assert_three_pages %{
        page_size: default,
        query_options: %{}
      }
    end

    test "with page nil query option returns error because pagination cannot be disabled" do
      assert_force_pagination_error()
    end

    test "with page size query option less than minimum page size returns error" do
      assert_minimum_size_error()
    end

    test "with page size query option between minimum and maximum page size uses overridden size",
         %{page_size: %{default: default}} do
      override = 4

      refute default == override

      assert_three_pages %{
        page_size: override,
        query_options: %{
          page: %Page{
            number: 1,
            size: override
          }
        }
      }
    end

    test "with page size query option greater than maximum page size returns error" do
      assert_maximum_size_error()
    end
  end

  # 110
  describe "list/1 with minimum page size with default page size without maximum page size" do
    setup [:minimum_page_size, :default_page_size]

    test "without page query option returns page with default page size", %{page_size: %{default: default}} do
      assert_three_pages %{
        page_size: default,
        query_options: %{}
      }
    end

    test "with page nil query option returns error because pagination cannot be disable" do
      assert_force_pagination_error()
    end

    test "with page size query option less than minimum page size returns error" do
      assert_minimum_size_error()
    end

    test "with page size greater than minimum page size uses overridden size",
         %{page_size: %{minimum: minimum, default: default}} do
      override = 4

      assert minimum < override
      refute default == override

      assert_three_pages %{
        page_size: override,
        query_options: %{
          page: %Page{
            number: 1,
            size: override
          }
        }
      }
    end
  end

  # 101
  describe "list/1 with minimmum page size without default page size with maximum page size" do
    setup [:minimum_page_size, :maximum_page_size]

    test "without page query option returns page with maximum page size", %{page_size: %{maximum: maximum}} do
      assert_three_pages %{
        page_size: maximum,
        query_options: %{}
      }
    end

    test "with page nil query option returns error because pagination cannot be disabled" do
      assert_force_pagination_error()
    end

    test "with page size query option less than minimum page size returns error" do
      assert_minimum_size_error()
    end

    test "with page size query option between minimum and maximum page size uses overridden size",
         %{page_size: %{minimum: minimum, maximum: maximum}} do
      override = 4

      assert minimum < override
      assert override < maximum

      assert_three_pages %{
        page_size: override,
        query_options: %{
          page: %Page{
            number: 1,
            size: override
          }
        }
      }
    end

    test "with page size query option greater than maximum page size returns error" do
      assert_maximum_size_error()
    end
  end

  # 100
  describe "list/1 with minimum page size without default page size without maximum page size" do
    setup :minimum_page_size

    test "without page query option returns page with minimum page size", %{page_size: %{minimum: minimum}} do
      assert_three_pages %{
        page_size: minimum,
        query_options: %{}
      }
    end

    test "with page nil query option returns error because pagination cannot be disabled" do
      assert_force_pagination_error()
    end

    test "with page size query option less than minimum page size returns error" do
      assert_minimum_size_error()
    end

    test "with page size query option between minimum and maximum page size uses overridden size",
         %{page_size: %{minimum: minimum}} do
      override = 4

      assert minimum < override

      assert_three_pages %{
        page_size: override,
        query_options: %{
          page: %Page{
            number: 1,
            size: override
          }
        }
      }
    end
  end

  # 011
  describe "list/1 without minimum page size with default page size with maximum page size" do
    setup [:default_page_size, :maximum_page_size]

    test "without page query option returns page with default page size", %{page_size: %{default: default}} do
      assert_three_pages %{
        page_size: default,
        query_options: %{}
      }
    end

    test "with page nil query option returns error because pagination cannot be disabled" do
      assert_force_pagination_error()
    end

    test "with page size query option less than maximum page size uses overridden size",
         %{page_size: %{default: default, maximum: maximum}} do
      override = 4

      refute default == override
      assert override < maximum

      assert_three_pages %{
        page_size: override,
        query_options: %{
          page: %Page{
            number: 1,
            size: override
          }
        }
      }
    end

    test "with page size query option greater than maximum page size returns error" do
      assert_maximum_size_error()
    end
  end

  # 010
  describe "list/1 without minimum page size with default page size without maximum page size" do
    setup :default_page_size

    test "without page query option returns page with default page size", %{page_size: %{default: default}} do
      assert_three_pages %{
        page_size: default,
        query_options: %{}
      }
    end

    test "with page nil query option disables pagination" do
      assert_pagination_disabled()
    end

    test "with page size query option not equal to default uses overridden size",
         %{page_size: %{default: default}} do
      override = 4

      refute default == override

      assert_three_pages %{
        page_size: override,
        query_options: %{
          page: %Page{
            number: 1,
            size: override
          }
        }
      }
    end

    test "valid filter filters the list", %{page_size: %{default: default}} do
      unfiltered_page_count = 6
      posts = Factory.insert_list(default * unfiltered_page_count, :test_post)

      # 3 pages, so still multipage, but total_size should differ from unpaginated total_size before of filter
      filtered_page_count = div(unfiltered_page_count, 2)
      expected_list_post_count = default * filtered_page_count

      filtered_posts = Enum.take(posts, expected_list_post_count)
      id_filter_value = Enum.map_join filtered_posts, ",", fn %{id: id} ->
        id
      end

      query_options = %{filters: %{"id" => id_filter_value}}

      assert {
               :ok,
               first_page_posts,
               %Pagination{
                 first: first_page = %Page{number: 1, size: ^default},
                 last: last_page = %Page{number: 3, size: ^default},
                 # multipage has next on first
                 next: second_page = %Page{number: 2, size: ^default},
                 # first page does not have previous
                 previous: nil
               }
             } = TestPosts.list(query_options)
      assert length(first_page_posts) == default

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
      assert length(second_page_posts) == default

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
      assert length(third_page_posts) == default

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

  # 001
  describe "list/1 without minimum page size without default page size with maximum page size" do
    setup :maximum_page_size

    test "without page query option returns page with maximum page size", %{page_size: %{maximum: maximum}} do
      assert_three_pages %{
        page_size: maximum,
        query_options: %{}
      }
    end

    test "with page nil query option returns error because pagination cannot be disabled" do
      assert_force_pagination_error()
    end

    test "with page size query option less than maximum page size uses overridden size",
         %{page_size: %{maximum: maximum}} do
      override = 4

      assert override < maximum

      assert_three_pages %{
        page_size: override,
        query_options: %{
          page: %Page{
            number: 1,
            size: override
          }
        }
      }
    end

    test "with page size query option greater than maximum page size returns error" do
      assert_maximum_size_error()
    end
  end

  # 000
  describe "list/1 without minimum page size without default page size without maximum page size" do
    test "without page query option returns returns unpaginated" do
      assert_pagination_disabled()
    end

    test "with page nil query option returns unpaginate" do
      assert_pagination_disabled()
    end

    test "with page size query option uses overridden size" do
      override = 4

      assert_three_pages %{
        page_size: override,
        query_options: %{
          page: %Page{
            number: 1,
            size: override
          }
        }
      }
    end

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

  defp assert_force_pagination_error do
    assert {
             :error,
             %Document{
               errors: [
                 %Error{
                   source: %Source{
                     pointer: "/page"
                   },
                   status: "422",
                   title: "Pagination cannot be disabled"
                 }
               ]
             }
           } = TestPosts.list(%{page: nil})
  end

  defp assert_maximum_size_error() do
    assert {
             :error,
             %Document{
               errors: [
                 %Error{
                   detail: "Page size (6) must be less than or equal to maximum (5)",
                   meta: %{
                     "maximum" => 5,
                     "size" => 6
                   },
                   source: %Source{
                     pointer: "/page/size"
                   },
                   status: "422",
                   title: "Page size must be less than or equal to maximum"
                 }
               ],
             }
           } = TestPosts.list(%{page: %Page{number: 1, size: 6}})
  end

  defp assert_minimum_size_error() do
    assert {
             :error,
             %Document{
               errors: [
                 %Error{
                   detail: "Page size (1) must be greater than or equal to minimum (2)",
                   meta: %{
                     "minimum" => 2,
                     "size" => 1
                   },
                   source: %Source{
                     pointer: "/page/size"
                   },
                   status: "422",
                   title: "Page size must be greater than or equal to minimum"
                 }
               ]
             }
           } = TestPosts.list(%{page: %Page{number: 1, size: 1}})
  end

  defp assert_pagination_disabled do
    assert {:ok, _, nil} = TestPosts.list(%{page: nil})
  end

  defp assert_three_pages(%{page_size: page_size, query_options: query_options}) do
    test_posts = Factory.insert_list(page_size * 3, :test_post)

    assert {
             :ok,
             first_page_test_posts,
             %Pagination{
               first: first_page = %Page{number: 1, size: ^page_size},
               last: last_page = %Page{number: 3, size: ^page_size},
               # multipage has next on first
               next: second_page = %Page{number: 2, size: ^page_size},
               # first page does not have previous
               previous: nil
             }
           } = TestPosts.list(query_options)
    assert length(first_page_test_posts) == page_size

    assert {
             :ok,
             second_page_test_posts,
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
    assert length(second_page_test_posts) == page_size

    assert {
             :ok,
             third_page_test_posts,
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
    assert length(third_page_test_posts) == page_size

    list_test_post_id_set = Enum.reduce(
      [first_page_test_posts, second_page_test_posts, third_page_test_posts],
      MapSet.new,
      fn page_test_posts, acc ->
        Enum.into(page_test_posts, acc, &to_id/1)
      end
    )

    assert list_test_post_id_set == id_set(test_posts)
  end

  # Needs to be between minimum and maximum.  It could be one of those values, but we need to be able to differentiate
  # between default using used and maximum being used when no default is set
  defp default_page_size(context), do: put_in_page_size(context, :default, 3)

  defp id_set(resources) when is_list(resources), do: Enum.into(resources, MapSet.new(), &to_id/1)

  # Needs to be greater than default, but leave a space for an override
  defp maximum_page_size(context), do: put_in_page_size(context, :maximum, 5)

  # not 1, so there's still a valid size, 1, that can be used to test the request is rejected to violating the minimum
  # and not just being an invalid size.
  defp minimum_page_size(context), do: put_in_page_size(context, :minimum, 2)

  defp put_in_page_size(context, key, value) do
    on_exit fn ->
      Application.delete_env(:calcinator, TestPosts)
    end

    page_size = context
                |> Map.get(:page_size, %{})
                |> Map.put(key, value)

    Application.put_env(:calcinator, TestPosts, page_size: Enum.to_list(page_size))

    Map.put(context, :page_size, page_size)
  end

  defp to_id(%{id: id}), do: id
end
