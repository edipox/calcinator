defmodule Calcinator.ControllerTest do
  alias Calcinator.{Authorization.Cant, Meta.Beam, TestAuthorView, TestPostView}
  alias Calcinator.Resources.{TestAuthor, TestPost}
  alias Calcinator.Resources.Ecto.Repo.{Factory, TestAuthors, TestPosts}
  alias Calcinator.Resources.Ecto.Repo.Repo
  alias Plug.Conn

  import ExUnit.CaptureLog
  import Plug.Conn, only: [put_req_header: 3]
  import Phoenix.ConnTest, only: [build_conn: 0, json_response: 2, response: 2]

  use ExUnit.Case, async: true

  # Callbacks

  setup do
    Application.put_env(:calcinator, TestAuthors, [])

    conn = build_conn()
           |> put_req_header("accept", "application/vnd.api+json")
           |> put_req_header("content-type", "application/vnd.api+json")

    [conn: conn]
  end

  # Tests

  doctest Calcinator.Controller

  describe "create/3" do
    test "{:ok, renderer}", %{conn: conn} do
      conn = Calcinator.Controller.create(
        conn,
        %{
          "data" => %{
            "type" => "test-authors",
            "attributes" => %{
              "name" => "Alice"
            }
          },
          "meta" => checkout_meta()
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{
               "data" => %{
                 "type" => "test-authors",
                 "attributes" => %{
                   "name" => "Alice"
                 }
               }
             } = json_response(conn, :created)
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn = Calcinator.Controller.create(
        conn,
        %{
          "data" => %{
            "type" => "test-authors",
            "attributes" => %{
              "name" => "Alice"
            }
          },
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      conn = Calcinator.Controller.create(
        conn,
        %{
          "data" => %{
            "type" => "test-authors",
            "attributes" => %{
              "name" => "Alice"
            }
          }
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [insert: {:error, :timeout}])

      conn = Calcinator.Controller.create(
        conn,
        %{
          "data" => %{
            "type" => "test-authors",
            "attributes" => %{
              "name" => "Alice"
            }
          },
          "meta" => checkout_meta()
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      conn = Calcinator.Controller.create(
        conn,
        %{
          "data" => %{
            "type" => "test-authors",
            "attributes" => %{
              "name" => "Alice"
            }
          },
          "meta" => checkout_meta()
        },
        %Calcinator{
          authorization_module: Cant,
          ecto_schema_module: TestAuthor,
          resources_module: TestAuthors,
          view_module: TestAuthorView
        }
      )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      conn = Calcinator.Controller.create(
        conn,
        %{
          "data" => %{
          },
          "meta" => checkout_meta(),
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 2
      assert %{
               "detail" => "`/data/type` is missing",
               "meta" => %{
                 "child" => "type"
               },
               "source" => %{
                 "pointer" => "/data"
               },
               "status" => "422",
               "title" => "Child missing"
             } in errors
      assert %{
               "detail" => "`/data/id` is missing",
               "meta" => %{
                 "child" => "id"
               },
               "source" => %{
                 "pointer" => "/data"
               },
               "status" => "422",
               "title" => "Child missing"
             } in errors
    end

    test "{:error, Ecto.Changeset.t}", %{conn: conn} do
      conn = Calcinator.Controller.create(
        conn,
        %{
          "data" => %{
            "type" => "test-authors",
            "attributes" => %{}
          },
          "meta" => checkout_meta()
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1
      assert %{
               "detail" => "name can't be blank",
               "source" => %{
                 "pointer" => "/data/attributes/name"
               },
               "title" => "can't be blank"
             } in errors
    end
  end

  describe "delete/3" do
    test ":ok", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert response(conn, :no_content) == ""
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => -1,
          "meta" => checkout_meta()
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_not_found(conn, "id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => id
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout} from Calcinator.Resources.get/2", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [get: {:error, :timeout}])

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :timeout} from Calcinator.Resources.delete/1", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [delete: {:error, :timeout}])

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{
          authorization_module: Cant,
          ecto_schema_module: TestAuthor,
          resources_module: TestAuthors,
          view_module: TestAuthorView
        }
      )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => id,
          "include" => "post",
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1
      assert %{
               "detail" => "`post` is an unknown relationship path",
               "meta" => %{
                 "relationship_path" => "post"
               },
               "source" => %{
                 "parameter" => "include"
               },
               "title" => "Unknown relationship path"
             } in errors
    end

    test "{:error, Ecto.Changeset.t}", %{conn: conn} do
      meta = checkout_meta()
      author = %TestAuthor{id: id} = Factory.insert(:test_author)
      Factory.insert(:test_post, author: author)

      conn = Calcinator.Controller.delete(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1
      assert %{
               "detail" => "posts are still associated with this entry",
               "source" => %{
                 "pointer" => "/data/relationships/posts"
               },
               "title" => "are still associated with this entry"
             } in errors
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      assert_error_reason :delete, fn ->
        Calcinator.Controller.delete(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end
    end
  end

  describe "get_related_resource/3" do
    test "{:ok, rendered} for belongs_to", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: author = %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.get_related_resource(
        conn,
        %{
          "post_id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
      )

      assert json_response(conn, :ok) ==
               %{
                 "jsonapi" => %{
                   "version" => "1.0"
                 },
                 "data" => %{
                   "type" => "test-authors",
                   "id" => to_string(author.id),
                   "attributes" => %{
                     "name" => author.name
                   },
                   "links" => %{
                     "self" => "/api/v1/test-posts/#{id}/author"
                   },
                   "relationships" => %{
                     "posts" => %{}
                   }
                 }
               }
    end

    test "{:ok, rendered} for has_many", %{conn: conn} do
      meta = checkout_meta()
      post = %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn = Calcinator.Controller.get_related_resource(
        conn,
        %{
          "author_id" => author_id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"data" => data, "links" => links} = json_response(conn, :ok)

      assert is_list(data)
      assert length(data) == 1
      assert %{
               "type" => "test-posts",
               "id" => to_string(post.id),
               "attributes" => %{
                 "body" => post.body
               },
               "links" => %{
                 "self" => "/api/v1/test-posts/#{post.id}"
               }
             } in data

      assert links == %{"self" => "/api/v1/test-authors/#{author_id}/posts"}
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      meta = checkout_meta()

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.get_related_resource(
        conn,
        %{
          "post_id" => -1,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
      )

      assert_not_found(conn, "post_id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.get_related_resource(
        conn,
        %{
          "post_id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
      )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.get_related_resource(
        conn,
        %{
          "post_id" => id
        },
        %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
      )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [get: {:error, :timeout}])

      meta = checkout_meta()
      %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn = Calcinator.Controller.get_related_resource(
        conn,
        %{
          "author_id" => author_id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.get_related_resource(
        conn,
        %{
          "post_id" => id,
          "meta" => meta
        },
        %Calcinator{
          authorization_module: Cant,
          ecto_schema_module: TestPost,
          resources_module: TestPosts,
          view_module: TestPostView
        }
      )

      assert_unauthorized(conn)
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      assert_error_reason :get, fn ->
        Calcinator.Controller.get_related_resource(
          conn,
          %{
            "author_id" => author_id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end
    end
  end

  describe "index/3" do
    test "{:ok, rendered}", %{conn: conn} do
      meta = checkout_meta()
      count = 2
      test_authors = Factory.insert_list(count, :test_author)

      conn = Calcinator.Controller.index(
        conn,
        %{
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"data" => data} = json_response(conn, :ok)
      assert is_list(data)
      assert length(data) == count

      Enum.each test_authors, fn test_author ->
        assert test_author_resource(test_author) in data
      end
    end

    test "{:error, {:page_size_must_be_less_than_or_equal_to_maximum, %{maximum: maximum, size: size}}}",
         %{conn: conn} do
      maximum = 1
      size = 2

      Application.put_env(
        :calcinator,
        TestAuthors,
        page_size: [
          maximum: maximum
        ]
      )

      meta = checkout_meta()

      conn = Calcinator.Controller.index(
        conn,
        %{
          "meta" => meta,
          "page" => %{
            "number" => 1,
            "size" => size
          }
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, :unprocessable_entity)
      assert is_list(errors)
      assert length(errors) == 1
      assert %{
               "detail" => "Page size (#{size}) must be less than or equal to maximum (#{maximum})",
               "meta" => %{
                 "maximum" => maximum,
                 "size" => size
               },
               "source" => %{
                 "pointer" => "/page/size"
               },
               "status" => "422",
               "title" => "Page size must be less than or equal to maximum"
             } in errors
    end

    test "{:error, {:page_size_must_be_greater_than_or_equal_to_minimum, %{minimum: minimum, size: size}}}",
         %{conn: conn} do
      minimum = 2
      size = 1

      Application.put_env(
        :calcinator,
        TestAuthors,
        page_size: [
          minimum: minimum
        ]
      )

      meta = checkout_meta()

      conn = Calcinator.Controller.index(
        conn,
        %{
          "meta" => meta,
          "page" => %{
            "number" => 1,
            "size" => size
          }
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, :unprocessable_entity)
      assert is_list(errors)
      assert length(errors) == 1
      assert %{
               "detail" => "Page size (#{size}) must be greater than or equal to minimum (#{minimum})",
               "meta" => %{
                 "minimum" => minimum,
                 "size" => size
               },
               "source" => %{
                 "pointer" => "/page/size"
               },
               "status" => "422",
               "title" => "Page size must be greater than or equal to minimum"
             } in errors
    end

    test "{:error, :pagination_cannot_be_disabled}", %{conn: conn} do
      Application.put_env(
        :calcinator,
        TestAuthors,
        page_size: [
          minimum: 1
        ]
      )

      meta = checkout_meta()

      conn = Calcinator.Controller.index(
        conn,
        %{
          "meta" => meta,
          "page" => nil
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, :unprocessable_entity)
      assert is_list(errors)
      assert length(errors) == 1
      assert %{
               "source" => %{
                 "pointer" => "/page"
               },
               "status" => "422",
               "title" => "Pagination cannot be disabled"
             } in errors
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn = Calcinator.Controller.index(
        conn,
        %{
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      count = 2
      Factory.insert_list(count, :test_author)

      conn = Calcinator.Controller.index(
        conn,
        %{},
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [list: {:error, :timeout}])
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)

      conn = Calcinator.Controller.index(
        conn,
        %{
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)

      conn = Calcinator.Controller.index(
        conn,
        %{
          "meta" => meta
        },
        %Calcinator{
          authorization_module: Cant,
          ecto_schema_module: TestAuthor,
          resources_module: TestAuthors,
          view_module: TestAuthorView
        }
      )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      meta = checkout_meta()
      count = 2
      Factory.insert_list(count, :test_author)

      conn = Calcinator.Controller.index(
        conn,
        %{
          "include" => "post",
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1
      assert %{
               "detail" => "`post` is an unknown relationship path",
               "meta" => %{
                 "relationship_path" => "post"
               },
               "source" => %{
                 "parameter" => "include"
               },
               "title" => "Unknown relationship path"
             } in errors
    end
  end

  describe "show/3" do
    test "{:ok, rendered}", %{conn: conn} do
      meta = checkout_meta()
      test_author = Factory.insert(:test_author)

      conn = Calcinator.Controller.show(
        conn,
        %{
          "id" => test_author.id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"data" => data} = json_response(conn, :ok)
      assert data == test_author_resource(test_author)
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      meta = checkout_meta()

      conn = Calcinator.Controller.show(
        conn,
        %{
          "id" => -1,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_not_found(conn, "id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn = Calcinator.Controller.show(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.show(
        conn,
        %{
          "id" => id
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [get: {:error, :timeout}])
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.show(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.show(
        conn,
        %{
          "id" => id,
          "meta" => meta
        },
        %Calcinator{
          authorization_module: Cant,
          ecto_schema_module: TestAuthor,
          resources_module: TestAuthors,
          view_module: TestAuthorView
        }
      )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.show(
        conn,
        %{
          "id" => id,
          "include" => "post",
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1
      assert %{
               "detail" => "`post` is an unknown relationship path",
               "meta" => %{
                 "relationship_path" => "post"
               },
               "source" => %{
                 "parameter" => "include"
               },
               "title" => "Unknown relationship path"
             } in errors
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      assert_error_reason :get, fn ->
        Calcinator.Controller.show(
          conn,
          %{
            "id" => id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end
    end
  end

  describe "show_relationship/3" do
    test "{:ok, rendered} for belongs_to", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: author = %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/relationship/author`
      conn = Calcinator.Controller.show_relationship(
        conn,
        %{
          "post_id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
      )

      assert json_response(conn, :ok) ==
               %{
                 "jsonapi" => %{
                   "version" => "1.0"
                 },
                 "data" => %{
                   "id" => to_string(author.id),
                   "type" => "test-authors"
                 },
                 "links" => %{
                   "related" => "/api/v1/test-posts/#{id}/author",
                   "self" => "/api/v1/test-posts/#{id}/relationships/author"
                 }
               }
    end

    test "{:ok, rendered} for has_many", %{conn: conn} do
      meta = checkout_meta()
      post = %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn = Calcinator.Controller.show_relationship(
        conn,
        %{
          "author_id" => author_id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"data" => data, "links" => links} = json_response(conn, :ok)

      assert is_list(data)
      assert length(data) == 1
      assert %{
               "type" => "test-posts",
               "id" => to_string(post.id)
             } in data

      assert links == %{
               "related" => "/api/v1/test-authors/#{author_id}/posts",
               "self" => "/api/v1/test-authors/#{author_id}/relationships/posts"
             }
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      meta = checkout_meta()

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.show_relationship(
        conn,
        %{
          "post_id" => -1,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
      )

      assert_not_found(conn, "post_id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.show_relationship(
        conn,
        %{
          "post_id" => id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
      )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.show_relationship(
        conn,
        %{
          "post_id" => id
        },
        %Calcinator{ecto_schema_module: TestPost, resources_module: TestPosts, view_module: TestPostView}
      )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [get: {:error, :timeout}])

      meta = checkout_meta()
      %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      # route like `/authors/:author_id/posts`
      conn = Calcinator.Controller.show_relationship(
        conn,
        %{
          "author_id" => author_id,
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{author: %TestAuthor{}, id: id} = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestAuthorView})
      conn = Conn.assign(conn, :source, %{association: :author, id_key: "post_id"})

      # route like `/posts/:post_id/author`
      conn = Calcinator.Controller.show_relationship(
        conn,
        %{
          "post_id" => id,
          "meta" => meta
        },
        %Calcinator{
          authorization_module: Cant,
          ecto_schema_module: TestPost,
          resources_module: TestPosts,
          view_module: TestPostView
        }
      )

      assert_unauthorized(conn)
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()
      %TestPost{
        author: %TestAuthor{
          id: author_id
        }
      } = Factory.insert(:test_post)

      # done by route.ex definition of route
      conn = Conn.assign(conn, :related, %{view_module: TestPostView})
      conn = Conn.assign(conn, :source, %{association: :posts, id_key: "author_id"})

      assert_error_reason :get, fn ->
        Calcinator.Controller.show_relationship(
          conn,
          %{
            "author_id" => author_id,
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end
    end
  end

  describe "update/3" do
    test "{:ok, rendered}", %{conn: conn} do
      meta = checkout_meta()
      test_author = %TestAuthor{id: id} = Factory.insert(:test_author, name: "Alice")

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          },
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"data" => data} = json_response(conn, :ok)
      assert data == test_author_resource(%{test_author | name: "Eve"})
    end

    # has happened when the `carrot_rpc` servers in Ruby crash with a 500 Internal Server error
    test "{:error, :bad_gateway}", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [{:update, {:error, :bad_gateway}}])

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author, name: "Alice")

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          },
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, :bad_gateway)
      assert is_list(errors)
      assert length(errors) == 1
      assert %{
               "status" => "502",
               "title" => "Bad Gateway"
             } in errors
    end

    test "{:error, {:not_found, _}}", %{conn: conn} do
      id = -1
      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          },
          "meta" => checkout_meta()
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_not_found(conn, "id")
    end

    test "{:error, :sandbox_access_disallowed}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)
      Ecto.Adapters.SQL.Sandbox.checkin(Repo)

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          },
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandox_access_disallowed(conn)
    end

    test "{:error, :sandbox_token_missing}", %{conn: conn} do
      :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          }
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_sandbox_token_missing(conn)
    end

    test "{:error, :timeout} from Calcinator.Resources.get/2", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [get: {:error, :timeout}])

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          },
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :timeout} from Calcinator.Resources.update/1", %{conn: conn} do
      Application.put_env(:calcinator, TestAuthors, [update: {:error, :timeout}])

      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          },
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert_timeout(conn)
    end

    test "{:error, :unauthorized}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          },
          "meta" => meta
        },
        %Calcinator{
          authorization_module: Cant,
          ecto_schema_module: TestAuthor,
          resources_module: TestAuthors,
          view_module: TestAuthorView
        }
      )

      assert_unauthorized(conn)
    end

    test "{:error, Alembic.Document.t}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => "Eve"
            }
          },
          "include" => "post",
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1
      assert %{
               "detail" => "`post` is an unknown relationship path",
               "meta" => %{
                 "relationship_path" => "post"
               },
               "source" => %{
                 "parameter" => "include"
               },
               "title" => "Unknown relationship path"
             } in errors
    end

    test "{:error, Ecto.Changeset.t}", %{conn: conn} do
      meta = checkout_meta()
      author = %TestAuthor{id: id} = Factory.insert(:test_author)
      Factory.insert(:test_post, author: author)

      conn = Calcinator.Controller.update(
        conn,
        %{
          "id" => id,
          "data" => %{
            "type" => "test-authors",
            "id" => to_string(id),
            "attributes" => %{
              "name" => nil
            }
          },
          "meta" => meta
        },
        %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
      )

      assert %{"errors" => errors} = json_response(conn, 422)
      assert length(errors) == 1
      assert %{
               "detail" => "name can't be blank",
               "source" => %{
                 "pointer" => "/data/attributes/name"
               },
               "title" => "can't be blank"
             } in errors
    end

    test "{:error, reason}", %{conn: conn} do
      meta = checkout_meta()
      %TestAuthor{id: id} = Factory.insert(:test_author)

      assert_error_reason :update, fn ->
        Calcinator.Controller.update(
          conn,
          %{
            "id" => id,
            "data" => %{
              "type" => "test-authors",
              "id" => to_string(id),
              "attributes" => %{
                "name" => "Eve"
              }
            },
            "meta" => meta
          },
          %Calcinator{ecto_schema_module: TestAuthor, resources_module: TestAuthors, view_module: TestAuthorView}
        )
      end
    end
  end

  # Functions

  ## Private Functions

  defp assert_error_reason(action, plug) do
    reason = "A secret reason"
    Application.put_env(:calcinator, TestAuthors, [{action, {:error, reason}}])

    log = capture_log [level: :error], fn ->
      conn = plug.()

      assert %{"errors" => errors} = json_response(conn, 500)
      assert [error] = errors
      assert %{
               "id" => error_id,
               "status" => "500",
               "title" => "Internal Server Error"
             } = error

      send self(), {:error_id, error_id}
    end

    error_id = receive do
      {:error_id, error_id} -> error_id
    end

    assert String.contains?(log, "id=#{error_id} reason=#{inspect(reason)}")
  end

  defp assert_not_found(conn, parameter) do
    assert %{"errors" => errors} = json_response(conn, :not_found)
    assert is_list(errors)
    assert length(errors) == 1
    assert %{
             "source" => %{
               "parameter" => parameter
             },
             "status" => "404",
             "title" => "Resource Not Found"
           } in errors
  end

  defp assert_sandox_access_disallowed(conn) do
    assert %{"errors" => errors} = json_response(conn, 422)
    assert length(errors) == 1
    assert %{
             "detail" => "Information in /meta/beam was not enough to grant access to the sandbox",
             "source" => %{
               "pointer" => "/meta/beam"
             },
             "status" => "422",
             "title" => "Sandbox Access Disallowed"
           } in errors
  end

  defp assert_sandbox_token_missing(conn) do
    assert %{"errors" => errors} = json_response(conn, 422)
    assert length(errors) == 1
    assert %{
             "detail" => "`/meta/beam` is missing",
             "meta" => %{
               "child" => "beam"
             },
             "source" => %{
               "pointer" => "/meta"
             },
             "status" => "422",
             "title" => "Child missing"
           } in errors
  end

  defp assert_timeout(conn) do
    assert %{"errors" => errors} = json_response(conn, 504)
    assert length(errors) == 1
    assert %{
             "status" => "504",
             "title" => "Gateway Timeout"
           } in errors
  end

  defp assert_unauthorized(conn) do
    assert %{"errors" => errors} = json_response(conn, 403)
    assert length(errors) == 1
    assert %{
             "detail" => "You do not have permission for this resource.",
             "status" => "403",
             "title" => "Forbidden"
           } in errors
  end

  defp checkout_meta do
    :ok = Ecto.Adapters.SQL.Sandbox.checkout(Repo)

    %{}
    |> Beam.put(Repo)
    |> Enum.into(
         %{},
         fn {key, value} ->
           {to_string(key), value}
         end
       )
  end

  defp test_author_resource(test_author = %TestAuthor{id: id}) do
    %{
      "type" => "test-authors",
      "id" => to_string(id),
      "attributes" => %{
        "name" => test_author.name
      },
      "links" => %{
        "self" => "/api/v1/test-authors/#{id}"
      },
      "relationships" => %{
        "posts" => %{}
      }
    }
  end
end
