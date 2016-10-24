defmodule Calcinator.JaSerializer.PhoenixView do
  @moduledoc """
  An adapter between `JaSerializer.PhoenixView` modules and `Calcinator.View`
  """

  alias Plug.Conn

  # Macros

  defmacro __using__(opts) when is_list(opts) do
    phoenix_view_module = Keyword.fetch!(opts, :phoenix_view_module)

    quote bind_quoted: [phoenix_view_module: phoenix_view_module], location: :keep do
      alias Calcinator.JaSerializer.PhoenixView

      # Behaviours

      @behaviour Calcinator.View

      # Functions

      def get_related_resource(data, options) do
        PhoenixView.get_related_resource(unquote(phoenix_view_module), data, options)
      end

      def index(data, options), do: PhoenixView.index(unquote(phoenix_view_module), data, options)

      def show(data, options), do: PhoenixView.show(unquote(phoenix_view_module), data, options)

      def show_relationship(data, options),
          do: PhoenixView.show_relationship(unquote(phoenix_view_module), data, options)
    end
  end

  # Functions

  def get_related_resource(phoenix_view_module, data, options = %{related: related, source: source})
      when is_nil(data) or is_map(data) do
    params = Map.get(options, :params, %{})
    subject = Map.get(options, :subject, nil)
    opts = params_to_render_opts(params)

    phoenix_view_module.render(
      "get_related_resource.json-api",
      %{
        conn: %Conn{
          assigns: %{
            subject: subject
          }
        },
        data: data,
        opts: opts,
        params: params,
        related: related,
        source: source
      }
    )
  end

  def index(phoenix_view_module, data, options) do
    params = Map.get(options, :params, %{})
    subject = Map.get(options, :subject, nil)
    opts = params_to_render_opts(params)
    # Only `:conn` option is passed to `attributes/2` callback, so have to fake `%Plug.Conn{}`
    phoenix_view_module.render("show.json-api", conn: %Conn{assigns: %{subject: subject}}, data: data, opts: opts)
  end

  def show(phoenix_view_module, data = %_{}, options) do
    params = Map.get(options, :params, %{})
    subject = Map.get(options, :subject, nil)
    opts = params_to_render_opts(params)
    phoenix_view_module.render("show.json-api", conn: %Conn{assigns: %{subject: subject}}, data: data, opts: opts)
  end

  def show_relationship(phoenix_view_module, data, options = %{related: related, source: source}) do
    params = Map.get(options, :params, %{})
    subject = Map.get(options, :subject, nil)
    opts = params_to_render_opts(params)

    phoenix_view_module.render(
      "show_relationship.json-api",
      %{
        conn: %Conn{
          assigns: %{
            subject: subject
          }
        },
        data: data,
        opts: opts,
        params: params,
        related: related,
        source: source
      }
    )
  end

  ## Private Functions

  defp params_to_render_opts(nil), do: []
  defp params_to_render_opts(params) when is_map(params) do
    # must only add :include to opts if "include" is in params so that default includes don't get overridden
    case Map.fetch(params, "include") do
      {:ok, include} ->
        [include: include]
      :error ->
        []
    end
  end
end