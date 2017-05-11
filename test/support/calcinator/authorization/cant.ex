defmodule Calcinator.Authorization.Cant do
  @moduledoc """
  `subject` cant do anything
  """

  @behaviour Calcinator.Authorization

  # Functions

  ## Calcinator.Authorization callbacks

  def can?(_, _, _), do: false
  def filter_associations_can(_, _, _) do
    raise "Should not be invoked"
  end
  def filter_can(_, _, _), do: []
end
