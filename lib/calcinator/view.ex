defmodule Calcinator.View do
  @moduledoc """
  A view for `Calcinator.Resources`
  """

  # Types

  @type pagination :: map

  @typedoc """
  `pagination` or `nil` if no pagination
  """
  @type maybe_pagination :: nil | pagination

  @typedoc """
  The raw request params that need to be parsed for view options
  """
  @type params :: %{String.t => term}

  @typedoc """
  The subject that must be authorized to view the individual attributes in the view.
  """
  @type subject :: term

  # Callbacks

  @doc """
  Renders list of `struct` with optional pagination, params, and subject (for view-level authorization of individual
  attributes). `base_uri` is required when `pagination` is present.
  """
  @callback index(
              [struct],
              %{
                optional(:base_uri) => URI.t,
                optional(:pagination) => maybe_pagination,
                optional(:params) => params,
                optional(:subject) => subject
              }
            ) :: iodata

  @doc """
  Renders the show iodata for the given `struct` and optional params and subject (for view-level authorization of
  individual attributes).
  """
  @callback show(struct, %{optional(:params) => params, optional(:subject) => subject}) :: iodata
end
