<!-- START doctoc generated TOC please keep comment here to allow auto update -->
<!-- DON'T EDIT THIS SECTION, INSTEAD RE-RUN doctoc TO UPDATE -->
**Table of Contents**  *generated with [DocToc](https://github.com/thlorenz/doctoc)*

- [Changelog](#changelog)
  - [v1.2.0](#v120)
    - [Enhancements](#enhancements)
    - [Bug Fixes](#bug-fixes)
  - [v1.1.0](#v110)
    - [Enhancements](#enhancements-1)
    - [Bug Fixes](#bug-fixes-1)

<!-- END doctoc generated TOC please keep comment here to allow auto update -->

# Changelog

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
