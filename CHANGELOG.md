<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Changelog](#changelog)
  - [v2.1.0](#v210)
    - [Enhancements](#enhancements)
    - [Bug Fixes](#bug-fixes)
  - [v2.0.0](#v200)
    - [Enhancements](#enhancements-1)
    - [Bug Fixes](#bug-fixes-1)
    - [Incompatible Changes](#incompatible-changes)
  - [v1.7.0](#v170)
    - [Enhancements](#enhancements-2)
    - [Bug Fixes](#bug-fixes-2)
  - [v1.6.0](#v160)
    - [Enhancements](#enhancements-3)
  - [v1.5.1](#v151)
    - [Bug Fixes](#bug-fixes-3)
  - [v1.5.0](#v150)
    - [Enhancements](#enhancements-4)
    - [Bug Fixes](#bug-fixes-4)
  - [v1.4.0](#v140)
    - [Enhancements](#enhancements-5)
  - [v1.3.0](#v130)
    - [Enhancements](#enhancements-6)
    - [Bug Fixes](#bug-fixes-5)
  - [v1.2.0](#v120)
    - [Enhancements](#enhancements-7)
    - [Bug Fixes](#bug-fixes-6)
  - [v1.1.0](#v110)
    - [Enhancements](#enhancements-8)
    - [Bug Fixes](#bug-fixes-7)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Changelog

## v2.1.0

### Enhancements
* [#12](https://github.com/C-S-D/calcinator/pull/12) - Regression tests that `%Calcinator{}` default `authorization_module` implements `Calcinator.Authorization` behaviour. - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#12](https://github.com/C-S-D/calcinator/pull/12) - Fix capitalization of `SubjectLess` when used as the `%Calcinator{}` default `authorization_module`. - [@KronicDeth](https://github.com/KronicDeth)

## v2.0.0

### Enhancements
* [#10](https://github.com/C-S-D/calcinator/pull/10) - [@KronicDeth](https://github.com/KronicDeth)
  * Explain why `relationships/2` is overridden in views
  * Routing docs for `get_related_resource` and `show_relationship`
  * Actions and related Authorization docs for `Calcinator.Controller`
  * Use `Ecto.Repo` `config/0` instead of requiring `sandboxed?/0` to be defined.

### Bug Fixes
* [#10](https://github.com/C-S-D/calcinator/pull/10) - [@KronicDeth](https://github.com/KronicDeth)
  * Add missing renames for README controllers
    * `alias InterpreterServerWeb.Controller` -> `alias Calcinator.Controller`
    * `use Controller.Resources,` -> `use Controller,`
  * Replace `use MyApp.Web, :view` with `use JaSerializer.PhoenixView`, so it doesn't require `MyApp.Web.view/0` to include `use JaSerializer.PhoenixView`
  * Renamed second `Author` `Ecto.Schema` modules to `Post`
  * Don't require `user` assign in `Calcinator.Controller`
  * Fix Elixir 1.4 `()` warnings.
* [#11](https://github.com/C-S-D/calcinator/pull/11) - `Code.ensure_loaded?(Phoenix.Controller)` can be used to protect `Calcinator.Controller.Error` and `Calcinator.Controller`, so that it is not defined when its dependency, `Phoenix.Controller` is not available.  Without this change, `(CompileError) lib/calcinator/controller/error.ex:12: module Phoenix.Controller is not loaded and could not be found` is raised in retort. - [@KronicDeth](https://github.com/KronicDeth)

### Incompatible Changes
* [#10](https://github.com/C-S-D/calcinator/pull/10) - Instead of requiring user assign in `Plug.Conn` to get `subject` for `%Calcinator{}`, a private key, `:calcinator_subject`, will be used using `Plug.Conn.put_private`.  The `subject` will be stored using `Calcinator.Controller.put_subject` and retrieved with `Calcinator.Controller.get_subject`.  Calling `put_subject` in a plug is shown in README and `Calcinator.Controller` examples. - [@KronicDeth](https://github.com/KronicDeth)

## v1.7.0

### Enhancements
* [#9](https://github.com/C-S-D/calcinator/pull/9) - Examples for how to `use Calcinator.Resources.Ecto.Repo` in `Calcinator.Resources.Ecto.Repo`'s `@moduledoc` - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#9](https://github.com/C-S-D/calcinator/pull/9) - Add missing `ecto_schema_module/0` callback to `README` example of `use Calcinator.Resources.Ecto.Repo` - [@KronicDeth](https://github.com/KronicDeth)

## v1.6.0

### Enhancements
* [#8](https://github.com/C-S-D/calcinator/pull/8) - [@KronicDeth](https://github.com/KronicDeth)
  * `use Calcinator.Controller` can be used inside a `Phoenix` controller to define JSONAPI actions.
  * `Calcinator.Controller.Error` defines functions for JSONAPI formatted errors that `Calcinator.Controller` may respond with.
  * Document how to use `Calcinator.Controller` to access `Retort.Client.Generic` backed `Calcinator.Resource`
  * Document how to use `Calcinator.Controller` to access `Calcinator.Resources.Ecto.Repo`

## v1.5.1

### Bug Fixes
* [#7](https://github.com/C-S-D/calcinator/pull/7) - `preload(module, queryable, opts)` returns `{:ok, query}` instead of just `query` now. - [@KronicDeth](https://github.com/KronicDeth)

## v1.5.0

### Enhancements
* [#6](https://github.com/C-S-D/calcinator/pull/6) - [@KronicDeth](https://github.com/KronicDeth)
  * Add `{:error, :ownership}` ∀ `Calcinator.Resources` callbacks
  * Add `{:error, :ownership}` ∀ `Calcinator` actions

### Bug Fixes
* [#6](https://github.com/C-S-D/calcinator/pull/6) - Previously `get` and `list` were the only `Calcinator.Resources.Ecto.Repo` functions that converted `DBConnection.OwnershipError` to `{:error, :ownership}`, but the other `Ecto.Repo` calls could also throw the Error, so all calls need to be protected for consistency. - [@KronicDeth](https://github.com/KronicDeth)

## v1.4.0

### Enhancements
* [#4](https://github.com/C-S-D/calcinator/pull/4) - `use Calcinator.Resources.Ecto.Repo` will define the callbacks for `Calcinator.Resources` backed by an `Ecto.Repo`.  The only callbacks that are required then are `ecto_schema_module/0`, `full_associations/1` and `repo/0`. - [@KronicDeth](https://github.com/KronicDeth)
* [#5](https://github.com/C-S-D/calcinator/pull/5) - [@KronicDeth](https://github.com/KronicDeth)
  * Update to `credo` `0.5.3`
  * Update to `ja_serializer` `0.11.2`

## v1.3.0

### Enhancements
* [#3](https://github.com/C-S-D/calcinator/pull/3) - [@KronicDeth](https://github.com/KronicDeth)
  * `Calcinator.Authorization` implementations
    * `Calcinator.Authorization.SubjectLess` allows all `action`s on all `target`s, but only if the passed `subject` is `nil`.  Use it for when you don't actually want authorization checks.
  * Document Steps and Returns of `Calcinator` actions.  Steps make it clearer which parts of `state` are used when.  Returns explain why a given return happens.
  * Document and clarify `Calcinator.Authorization` calling patterns
    * Document each callback with the target shape for each action.
   * Break up the callbacks into multiple signatures for the different call site


### Bug Fixes
* [#3](https://github.com/C-S-D/calcinator/pull/3) - [@KronicDeth](https://github.com/KronicDeth)
  * Add missing related `Calcinator.View` callbacks, `get_related_resource` and `show_relationship`, that are needed for their respective functions in `Calcinator`.
  * Add missing newline at end of file.
  * Remove `argN` arguments in docs by naming arguments in specs
  * Remove extra blank line

## v1.2.0

### Enhancements
* [#2](https://github.com/C-S-D/calcinator/pull/2) - Doctests for `Calcinator.Resources.attribute_to_field/2` - [@KronicDeth](https://github.com/KronicDeth)

### Bug Fixes
* [#2](https://github.com/C-S-D/calcinator/pull/2) - `Calcinator.Resources.attribute_to_field/2` now works with virtual fields. - [@KronicDeth](https://github.com/KronicDeth)

## v1.1.0

### Enhancements
* [#1](https://github.com/C-S-D/calcinator/pull/1) - Expose `attribute_to_field` that was used in `Calcinator.Resources.Sort` as it is useful in other places instead of using `String.to_existing_atom`, which doesn't handle the hyphenation and can fail if the atom hasn't been loaded yet. - [@KronicDeth](https://github.com/KronicDeth)


### Bug Fixes
* [#1](https://github.com/C-S-D/calcinator/pull/1) - [@KronicDeth](https://github.com/KronicDeth)
  * Add missing top-level files to extras:
    * `CHANGELOG.md`
    * `CODE_OF_CONDUCT.md`
    * `CONTRIBUTING.md`
    * `LICENSE.md`
