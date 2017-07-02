defmodule Calcinator.Resources.PageTest do
  @moduledoc """
  Tests `Calcinator.Resources.Page`
  """

  alias Alembic.{Document, Error, Source}
  alias Calcinator.Resources.Page

  import ExUnit.CaptureIO

  use ExUnit.Case,
      # MUST be false as `capture_io(:stderr, ...)` is used to check for deprecation warnings
      async: false

  doctest Page

  # previous doc tests that can't be doctests because deprecated from_params/1 is `@doc false`
  describe "from_params/1" do
    test "no page key then no pagination" do
      deprecated = fn ->
        assert Page.from_params(%{}) == {:ok, nil}
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.from_params/1` is deprecated"
             )
    end

    test "from json" do
      deprecated = fn ->
        assert Page.from_params(
                 %{
                   "page" => %{
                     "number" => 1,
                     "size" => 2
                   }
                 }
               )  == {:ok, %Page{number: 1, size: 2}}
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.from_params/1` is deprecated"
             )
    end

    test "from json integer" do
      deprecated = fn ->
        assert Page.from_params(%{"page" => 1}) == {
                 :error,
                 %Document{
                   errors: [
                     %Error{
                       detail: "`/page` type is not object",
                       meta: %{
                         "type" => "object"
                       },
                       source: %Source{
                         pointer: "/page"
                       },
                       status: "422",
                       title: "Type is wrong"
                     }
                   ]
                 }
               }
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.from_params/1` is deprecated"
             )
    end

    test "from json without page size" do
      deprecated = fn ->
        assert Page.from_params(
                 %{
                   "page" => %{
                     "number" => 1
                   }
                 }
               ) == {
                 :error,
                 %Document{
                   errors: [
                     %Error{
                       detail: "`/page/size` is missing",
                       meta: %{
                         "child" => "size"
                       },
                       source: %Source{
                         pointer: "/page"
                       },
                       status: "422",
                       title: "Child missing"
                     }
                   ]
                 }
               }
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.from_params/1` is deprecated"
             )
    end

    test "from json without page number" do
      deprecated = fn ->
        assert Page.from_params(
                 %{
                   "page" => %{
                     "size" => 10
                   }
                 }
               ) == {
                 :error,
                 %Document{
                   errors: [
                     %Error{
                       detail: "`/page/number` is missing",
                       meta: %{
                         "child" => "number"
                       },
                       source: %Source{
                         pointer: "/page"
                       },
                       status: "422",
                       title: "Child missing"
                     }
                   ]
                 }
               }
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.from_params/1` is deprecated"
             )
    end

    test "from json without positive page number" do
      deprecated = fn ->
        assert Page.from_params(
                 %{
                   "page" => %{
                     "number" => 0,
                     "size" => 10
                   }
                 }
               ) == {
                 :error,
                 %Document{
                   errors: [
                     %Error{
                       detail: "`/page/number` type is not positive integer",
                       meta: %{
                         "type" => "positive integer"
                       },
                       source: %Source{
                         pointer: "/page/number"
                       },
                       status: "422",
                       title: "Type is wrong"
                     }
                   ]
                 }
               }
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.from_params/1` is deprecated"
             )
    end

    test "from json without positive page size" do
      deprecated = fn ->
        assert Page.from_params(
                 %{
                   "page" => %{
                     "number" => 1,
                     "size" => 0
                   }
                 }
               ) == {
                 :error,
                 %Document{
                   errors: [
                     %Error{
                       detail: "`/page/size` type is not positive integer",
                       meta: %{
                         "type" => "positive integer"
                       },
                       source: %Source{
                         pointer: "/page/size"
                       },
                       status: "422",
                       title: "Type is wrong"
                     }
                   ]
                 }
               }
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.from_params/1` is deprecated"
             )
    end

    test "from params" do
      deprecated = fn ->
        assert Page.from_params(
                 %{
                   "page" => %{
                     "number" => "1",
                     "size" => "2"
                   }
                 }
               ) == {:ok, %Page{number: 1, size: 2}}
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.from_params/1` is deprecated"
             )
    end
  end

  describe "to_params/1" do
    test "with nil" do
      deprecated = fn ->
        assert Page.to_params(nil) == %{}
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.to_params/1` is deprecated"
             )
    end

    test "with Calcinator.Resources.Page.t" do
      deprecated = fn ->
        assert Page.to_params(%Page{number: 2, size: 5}) == %{
                 "page" => %{
                   "number" => 2,
                   "size" => 5
                 }
               }
      end

      assert String.contains?(
               capture_io(:stderr, deprecated),
               "`Calcinator.Resources.Page.to_params/1` is deprecated"
             )
    end
  end
end
