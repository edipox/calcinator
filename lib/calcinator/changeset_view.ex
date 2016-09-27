defmodule Calcinator.ChangesetView do
  @moduledoc """
  Attempts to show Ecto changeset errors in JSON:API compliant fashion.
  """

  alias JaSerializer.EctoErrorSerializer

  use JaSerializer.PhoenixView

  def render("error-object.json", changeset) do
    EctoErrorSerializer.format(changeset)
  end
end
