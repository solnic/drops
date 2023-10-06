## v0.1.0 - TBR

### Features

- Added `Drops.Contract` module for defining validation schemas with additional rules
- Added `Drops.Validator` module for running validation functions against input
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
