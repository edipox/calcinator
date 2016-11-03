defmodule Calcinator.Authorization do
  @moduledoc """
  Behaviour for `Calcinator.Resources.t` `authorization_module`
  """

  # Types

  @typedoc """
  The actions that must be handled by `can?/3`, `filter_associations_can/3`, and `filter_can/3`.
  """
  @type action :: :create | :delete | :index | :update | :show

  @typedoc """
  The subject that is trying to do the action and needs to be authorized by `authorization_module`
  """
  @type subject :: term

  @typedoc """
  The target of the `subject`'s action
  """
  @type target :: term

  # Callbacks

  @doc """
  Checks whether `subject` (from `Calcinator.Resources.t` `subject`) can perform `action` on `target`.
  """
  @callback can?(subject, action, target) :: boolean

  @doc """
  Reduces associations on `target` to only those where `can?(subject, action, associated_ascent)` is `true`.
  """
  @callback filter_associations_can(target, subject, action) :: target

  @doc """
  Reduces `targets` to only those elements where `can?(subject, action, targets_element)` is `true`.
  """
  @callback filter_can(targets :: [target], subject, action) :: [target]
end
