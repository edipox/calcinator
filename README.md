# Calcinator

Calcinator provides a standardized interface for processing JSONAPI request that is transport neutral.  CSD uses it
for both API controllers and RPC servers.

Calcinator uses [Alembic](https://github.com/C-S-D/alembic) to validate JSONAPI documents passed to the action functions
in `Calcinator`.  `Calcinator` supports the JSONAPI CRUD-style actions:
* `create`
* `delete`
* `get_related_resource`
* `index`
* `show`
* `show_relationship`
* `update`

Each action expects to be passed a `%Calcinator{}`.  The struct allow `Calcinator` to support converting JSONAPI
includes to associations (`associations_by_include`), authorization (`authorization_module` and `subject`),
`Ecto.Schema.t` interaction (`resources_module`), and JSONAPI document rendering (`view_module`).

## Authorization

`%Calcinator{}` `authorization_modules` need to implement the `Calcinator.Authorization` behaviour.

* `can?(subject, action, target) :: boolean`
* `filter_associations_can(target, subject, action) :: target`
* `filter_can(targets :: [target], subject, action) :: [target]`

The `can?(suject, action, target) :: boolean` matches the signature of the `Canada` protocol, but it is not required.

## Resources

`Calcinator.Resources` is a behaviour to supporting standard CRUD actions on an Ecto-based backing store.  This backing
store does not need to be a database that uses `Ecto.Repo`.  At CSD, we use `Calcinator.Resources` to hide the
differences between `Ecto.Repo` backed `Ecto.Schema.t` and RPC backed `Ecto.Schema.t` (where we use `Ecto` to do the
type casting.)

Because `Calcinator.Resources` need to work as an interface for both `Ecto.Repo` and RPC backed resources,
the callbacks and returns need to work for both, so all `Calcinator.Resources` implementations need to support
`allow_sandbox_access` and `sandboxed?` used for concurrent `Ecto.Repo` tests, but they also can return RPC error
messages like `{:error, :bad_gateway}` and `{:error, :timeout}`.

### Pagination

The `list` callback instead of returning just the list of resources, also accepts and returns (optional) pagination
information.  The pagination param format is documented in `Calcinator.Resources.Page`.

In addition to pagination in `page`, `Calcinator.Resources.query_options` supports `associations` for JSONAPI includes
(after being converted using `%Calcinator{}` `associations_by_include`), `filters` for JSONAPI filters that are passed
through directly, and `sorts` for JSONAPI sort.

## Installation

If [available in Hex](https://hex.pm/docs/publish), the package can be installed as:

  1. Add `calcinator` to your list of dependencies in `mix.exs`:

    ```elixir
    def deps do
      [{:calcinator, "~> 1.0.0"}]
    end
    ```

  2. Ensure `calcinator` is started before your application:

    ```elixir
    def application do
      [applications: [:calcinator]]
    end
    ```

