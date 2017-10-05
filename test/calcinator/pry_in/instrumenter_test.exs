defmodule Calcinator.PryIn.InstrumenterTest do
  use Calcinator.PryIn.Case

  import Calcinator.Resources.Ecto.Repo.Repo.Case

  alias Calcinator.Resources.Ecto.Repo.{Factory, TestAuthors, TestPosts}
  alias Calcinator.Resources.{TestAuthor, TestPost}
  alias Calcinator.{TestAuthorView, TestPostView}
  alias PryIn.{CustomTrace, InteractionStore}

  describe "calcinator_can/3" do
    test "in Calcinator.create/2" do
      meta = checkout_meta()

      %TestAuthor{id: author_id} = Factory.insert(:test_author)
      body = "First Post!"

      %{context: context, custom_metrics: custom_metrics} = custom_trace %{group: "TestPost", key: "create"}, fn ->
        assert {:ok, _} = Calcinator.create(
                 %Calcinator{
                   associations_by_include: %{
                     "author" => :author
                   },
                   ecto_schema_module: TestPost,
                   resources_module: TestPosts,
                   view_module: TestPostView
                 },
                 %{
                   "meta" => meta,
                   "data" => %{
                     "type" => "test-posts",
                     "attributes" => %{
                       "body" => body
                     },
                     "relationships" => %{
                       "author" => %{
                         "data" => %{
                           "type" => "test-authors",
                           "id" => to_string(author_id)
                         }
                       }
                     }
                   },
                   "include" => "author"
                 }
               )
      end

      custom_metric_count = 2

      assert length(context) == custom_metric_count * 2

      assert {"calcinator/can/actions/create/targets/Calcinator.Resources.TestPost/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/create/targets/Calcinator.Resources.TestPost/subject", "nil"} in context

      assert {"calcinator/can/actions/create/targets/%Ecto.Changeset{data: %Calcinator.Resources.TestPost{}}/" <>
              "authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/create/targets/%Ecto.Changeset{data: %Calcinator.Resources.TestPost{}}/subject",
               "nil"} in context

      assert length(custom_metrics) == custom_metric_count

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   function: "can/3",
                   key: "calcinator_can_create",
                   module: "Calcinator",
                 } = custom_metric
        end
      )
    end

    test "in Calcinator.delete/2" do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      %{context: context, custom_metrics: custom_metrics} = custom_trace %{group: "TestAuthor", key: "delete"}, fn ->
        :ok = Calcinator.delete(
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView},
          %{
            "id" => id,
            "meta" => meta
          }
        )
      end

      custom_metric_count = 1

      assert length(context) == custom_metric_count * 2

      assert {"calcinator/can/actions/delete/targets/%Calcinator.Resources.TestAuthor{}/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/delete/targets/%Calcinator.Resources.TestAuthor{}/subject",
               "nil"} in context

      assert length(custom_metrics) == custom_metric_count

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   function: "can/3",
                   key: "calcinator_can_delete",
                   module: "Calcinator",
                 } = custom_metric
        end
      )
    end

    test "in Calcinator.get_related_resource/3" do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      %{context: context, custom_metrics: custom_metrics} = custom_trace(
        %{group: "TestPost", key: "get_related_resource"},
        fn ->
          {:ok, _} = Calcinator.get_related_resource(
            %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView},
            %{
              "post_id" => id,
              "meta" => meta
            },
            %{
              related: %{
                view_module: TestAuthorView
              },
              source: %{
                association: :author,
                id_key: "post_id"
              }
            }
          )
        end
      )

      custom_metric_count = 2

      assert length(context) == custom_metric_count * 2

      assert {"calcinator/can/actions/show/targets/%Calcinator.Resources.TestPost{}/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/show/targets/%Calcinator.Resources.TestPost{}/subject",
               "nil"} in context

      assert {"calcinator/can/actions/show/targets/" <>
              "[%Calcinator.Resources.TestAuthor{}, %Calcinator.Resources.TestPost{}]/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/show/targets/" <>
              "[%Calcinator.Resources.TestAuthor{}, %Calcinator.Resources.TestPost{}]/subject",
               "nil"} in context

      assert length(custom_metrics) == custom_metric_count

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   function: "can/3",
                   key: "calcinator_can_show",
                   module: "Calcinator"
                 } = custom_metric
        end
      )
    end

    test "in Calcinator.index/3" do
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)

      %{context: context, custom_metrics: custom_metrics} = custom_trace %{group: "TestAuthor", key: "index"}, fn ->
        assert {:ok, %{"data" => data}} = Calcinator.index(
                 %Calcinator{
                   ecto_schema_module: TestAuthor,
                   resources_module: TestAuthors,
                   view_module: TestAuthorView
                 },
                 %{
                   "meta" => meta
                 },
                 %{base_uri: %URI{}}
               )

        assert length(data) == count
      end

      custom_metric_count = 1

      assert length(context) == custom_metric_count * 2

      assert {"calcinator/can/actions/index/targets/Calcinator.Resources.TestAuthor/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/index/targets/Calcinator.Resources.TestAuthor/subject",
               "nil"} in context

      assert length(custom_metrics) == 1

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   function: "can/3",
                   key: "calcinator_can_index",
                   module: "Calcinator",
                 } = custom_metric
        end
      )
    end

    test "in Calcinator.show/3" do
      meta = checkout_meta()
      test_author = Factory.insert(:test_author)

      %{context: context, custom_metrics: custom_metrics} = custom_trace %{group: "TestAuthor", key: "show"}, fn ->
        {:ok, _} = Calcinator.show(
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView},
          %{
            "id" => test_author.id,
            "meta" => meta
          }
        )
      end

      custom_metric_count = 1

      assert length(context) == custom_metric_count * 2

      assert {"calcinator/can/actions/show/targets/%Calcinator.Resources.TestAuthor{}/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/show/targets/%Calcinator.Resources.TestAuthor{}/subject",
               "nil"} in context

      assert length(custom_metrics) == custom_metric_count

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   function: "can/3",
                   key: "calcinator_can_show",
                   module: "Calcinator",
                 } = custom_metric
        end
      )
    end

    test "in Calcinator.show_relationship/3" do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      %{context: context, custom_metrics: custom_metrics} = custom_trace(
        %{group: "TestPost", key: "show_relationship"},
        fn ->
          {:ok, _} = Calcinator.show_relationship(
            %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView},
            %{
              "post_id" => id,
              "meta" => meta
            },
            %{
              related: %{
                view_module: TestAuthorView
              },
              source: %{
                association: :author,
                id_key: "post_id"
              }
            }
          )
        end
      )

      custom_metric_count = 2

      assert length(context) == custom_metric_count * 2

      assert {"calcinator/can/actions/show/targets/" <>
              "[%Calcinator.Resources.TestAuthor{}, %Calcinator.Resources.TestPost{}]/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/show/targets/" <>
              "[%Calcinator.Resources.TestAuthor{}, %Calcinator.Resources.TestPost{}]/subject",
               "nil"} in context
      assert {"calcinator/can/actions/show/targets/%Calcinator.Resources.TestPost{}/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/show/targets/%Calcinator.Resources.TestPost{}/subject",
               "nil"} in context

      assert length(custom_metrics) == custom_metric_count

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   function: "can/3",
                   key: "calcinator_can_show",
                   module: "Calcinator"
                 } = custom_metric
        end
      )
    end

    test "in Calcinator.update/3" do
      meta = checkout_meta()
      test_tag = Factory.insert(:test_tag)
      %TestPost{id: id} = Factory.insert(:test_post, tags: [test_tag])
      updated_body = "Updated Body"
      updated_test_tag = Factory.insert(:test_tag)

      %{context: context, custom_metrics: custom_metrics} = custom_trace %{group: "TestPost", key: "update"}, fn ->
        {:ok, _} = Calcinator.update(
          %Calcinator{
            associations_by_include: %{
              "author" => :author,
              "tags" => :tags
            },
            ecto_schema_module: TestPost,
            resources_module: TestPosts,
            view_module: TestPostView
          },
          %{
            "id" => to_string(id),
            "data" => %{
              "type" => "test-posts",
              "id" => to_string(id),
              "attributes" => %{
                "body" => updated_body
              },
              # Test `many_to_many` update does replacement
              "relationships" => %{
                "tags" => %{
                  "data" => [
                    %{
                      "type" => "test-tags",
                      "id" => to_string(updated_test_tag.id)
                    }
                  ]
                }
              }
            },
            "include" => "author,tags",
            "meta" => meta
          }
        )
      end

      custom_metric_count = 2

      assert length(context) == custom_metric_count * 2

      assert {"calcinator/can/actions/show/targets/%Calcinator.Resources.TestPost{}/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/show/targets/%Calcinator.Resources.TestPost{}/subject",
               "nil"} in context

      assert {"calcinator/can/actions/update/targets/%Ecto.Changeset{data: %Calcinator.Resources.TestPost{}}/" <>
              "authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/update/targets/%Ecto.Changeset{data: %Calcinator.Resources.TestPost{}}/subject",
               "nil"} in context

      assert length(custom_metrics) == custom_metric_count

      custom_metric_keys = Enum.map(custom_metrics, fn %PryIn.Interaction.CustomMetric{key: key} -> key end)

      assert "calcinator_can_show" in custom_metric_keys
      assert "calcinator_can_update" in custom_metric_keys

      assert_custom_metrics_filled(custom_metrics)

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{function: "can/3", module: "Calcinator"} = custom_metric
        end
      )
    end
  end

  # Functions

  ## Private Functions

  defp assert_custom_metrics_filled(custom_metrics) do
    Enum.each(
      custom_metrics,
      fn custom_metric ->
        assert %PryIn.Interaction.CustomMetric{
                 duration: duration,
                 file: file,
                 function: function,
                 key: key,
                 line: line,
                 module: module,
                 pid: pid
               } = custom_metric
        refute is_nil(function)
        refute is_nil(duration)
        refute is_nil(file)
        refute is_nil(key)
        refute is_nil(line)
        refute is_nil(module)
        refute is_nil(pid)
      end
    )
  end

  defp custom_trace(%{group: group, key: key}, fun) do
    CustomTrace.start(group: group, key: key)

    try do
      fun.()
    after
      CustomTrace.finish()
    end

    assert [
             %PryIn.Interaction{
               context: context,
               custom_group: ^group,
               custom_key: ^key,
               custom_metrics: custom_metrics,
               type: :custom_trace
             }
           ] = InteractionStore.get_state.finished_interactions

    assert is_list(context)

    assert is_list(custom_metrics)
    assert_custom_metrics_filled(custom_metrics)

    %{context: context, custom_metrics: custom_metrics}
  end
end
