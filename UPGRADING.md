# Upgrading

## v3.0.0

### `Calcinator.Resources.allow_sandbox_access/1` return types

`Calcinator.Resources.allow_sandbox_access/1` must now return `:ok | {:error, :sandbox_access_disallowed}`.  The previous `{:already, :allowed | :owner}` maps to `:ok` while `:not_found` maps to `{:error, :sandbox_access_disallowed}`.

#### `Calcinator` action returns

If you previously had total coverage for all return types from `Calcinator` actions, they now also return `{:error, :sandbox_access_disallowed}` and `{:error, :timeout}`.  Previously, instead of `{:error, :sandbox_access_disallowed}`, `:not_found` may been returned, but that was a bug that leaked an implementation detail from how `DBConnection.Ownership` works, so it was removed.

#### `Calcinator.Resources.delete` arguments

`Calcinator.Resources.delete` deletes a changeset instead of a resource struct to allow constraints to be added to the `Ecto.Changeset.t` so that database constraint errors are transformed to validation errors.  `Calcinator.delete` now takes, as a second argument, the `Calcinator.Resources.query_options`

If you used `use Calcinator.Resources.Ecto.Repo`, it now generates `delete/2` (instead of `delete/1`) that expects an `Ecto.Changeset.t` and `Calcinator.Resources.query_options` and calls `Calcinator.Resources.Ecto.Repo.delete/3`, which now expects a changeset instead of resource struct as the second argument and the query options as the third argument.

#### `Calcinator.Resources.query_options`

`:meta` is now a required key in `Calcinator.Resources.query_options` in order to allow `Calcinator.Meta.Beam` to be passed through for loopback chains.

`Calcinator.Meta.Beam.put_new_lazy/2` can be used to add the sandbox token to the meta only if its not already present.  It should be used in place of `Calcinator.Meta.Beam.put/2` whenever the pre-existing meta beam might need to be passed through.

