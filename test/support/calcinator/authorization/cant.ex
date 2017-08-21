defmodule Calcinator.Authorization.Cant do
  @moduledoc """
  `subject` cant do anything
  """

  @behaviour Calcinator.Authorization

  # Functions

  ## Calcinator.Authorization callbacks

  @impl Calcinator.Authorization
  def can?(_, _, _), do: false

  @impl Calcinator.Authorization
  def filter_associations_can(_, _, _) do
    raise "Should not be invoked"
  end

  @impl Calcinator.Authorization
  def filter_can(_, _, _), do: []
end
