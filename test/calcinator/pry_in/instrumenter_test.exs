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

      CustomTrace.start(group: "TestPost", key: "create")

      assert {:ok, _test_post_json} = Calcinator.create(
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

      CustomTrace.finish()

      assert [
               %PryIn.Interaction{
                 context: context,
                 custom_group: "TestPost",
                 custom_key: "create",
                 custom_metrics: custom_metrics,
                 type: :custom_trace
               }
             ] = InteractionStore.get_state.finished_interactions

      assert is_list(context)
      assert length(context) == 4

      assert {"calcinator/can/actions/create/targets/%Ecto.Changeset{data: %Calcinator.Resources.TestPost{}}/" <>
              "authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/create/targets/%Ecto.Changeset{data: %Calcinator.Resources.TestPost{}}/subject",
               "nil"} in context
      assert {"calcinator/can/actions/create/targets/Calcinator.Resources.TestPost/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/create/targets/Calcinator.Resources.TestPost/subject", "nil"} in context

      assert is_list(custom_metrics)
      assert length(custom_metrics) == 2

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   duration: duration,
                   file: file,
                   function: "can/3",
                   key: "calcinator_can_create",
                   line: line,
                   module: Calcinator,
                   pid: pid
                 } = custom_metric
          refute is_nil(duration)
          refute is_nil(file)
          refute is_nil(line)
          refute is_nil(pid)
        end
      )
    end

    test "in Calcinator.delete/2" do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      CustomTrace.start(group: "TestAuthor", key: "delete")

      :ok = Calcinator.delete(
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView},
        %{
          "id" => id,
          "meta" => meta
        }
      )

      CustomTrace.finish()

      assert [
               %PryIn.Interaction{
                 context: context,
                 custom_group: "TestAuthor",
                 custom_key: "delete",
                 custom_metrics: custom_metrics,
                 type: :custom_trace
               }
             ] = InteractionStore.get_state.finished_interactions

      assert is_list(context)
      assert length(context) == 2

      assert {"calcinator/can/actions/delete/targets/%Calcinator.Resources.TestAuthor{}/authorization_module",
               "Calcinator.Authorization.SubjectLess"} in context
      assert {"calcinator/can/actions/delete/targets/%Calcinator.Resources.TestAuthor{}/subject",
               "nil"} in context

      assert is_list(custom_metrics)
      assert length(custom_metrics) == 1

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   duration: duration,
                   file: file,
                   function: "can/3",
                   key: "calcinator_can_delete",
                   line: line,
                   module: Calcinator,
                   pid: pid
                 } = custom_metric
          refute is_nil(duration)
          refute is_nil(file)
          refute is_nil(line)
          refute is_nil(pid)
        end
      )
    end

    test "in Calcinator.get_related_resource/3" do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      CustomTrace.start(group: "TestPost", key: "get_related_resource")

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

      CustomTrace.finish()

      assert [
               %PryIn.Interaction{
                 context: context,
                 custom_group: "TestPost",
                 custom_key: "get_related_resource",
                 custom_metrics: custom_metrics,
                 type: :custom_trace
               }
             ] = InteractionStore.get_state.finished_interactions

      assert is_list(context)
      assert length(context) == 4

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

      assert is_list(custom_metrics)
      assert length(custom_metrics) == 2

      Enum.each(
        custom_metrics,
        fn custom_metric ->
          assert %PryIn.Interaction.CustomMetric{
                   duration: duration,
                   file: file,
                   function: "can/3",
                   key: "calcinator_can_show",
                   line: line,
                   module: Calcinator,
                   pid: pid
                 } = custom_metric
          refute is_nil(duration)
          refute is_nil(file)
          refute is_nil(line)
          refute is_nil(pid)
        end
      )
    end
  end
end
