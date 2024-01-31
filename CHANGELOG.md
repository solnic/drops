## v0.2.0 - TBD

### Features

- `Drops.Type` module that allows you to define custom types (via #36)
- `Drops.Type.Validator` protocol that allows you to define custom validators for your types
- Added built-in `Drops.Types.Number` type (issue #33)
- Added `union` to type definition DSL (issue #37)

### Fixes

- Warning about `conform` callback is gone (issue #34)

### Changes

- All built-in types have been refactored to use the validator protocol
- `Drops.Types.Sum` was renamed to `Drops.Types.Union`

## v0.1.1 - 2023-10-27

### Fixes

- [`Drops.Contract`] Rules are now correctly applied only to the root map (via #32)

## v0.1.0 - 2023-10-25

### Features

- Added `Drops.Contract` module for defining validation schemas with additional rules
- Added `Drops.Validator` module for running validation functions against input
- Added `Drops.Validator.Messages.DefaultBackend` that's configured by default in contracts
- Added `Drops.Types` module with the following built-in types:
  - `Drops.Types.Type` - basic type
  - `Drops.Types.List` - a list if member type
  - `Drops.Types.Map` - a map with typed keys
  - `Drops.Types.Sum` - a composition of two types
  - `Drops.Types.Cast` - a type that defines from-to casting types and caster options
- Added `Drops.Predicates` module which provides many common predicate functions like `filled?`, `gt?`, `size?` etc.
- Added `Drops.Casters` module which provides common type casting functions that can be used with the built-in types

## v0.0.0 - 2023-09-04

Reserving the package name
