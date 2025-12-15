# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.2] - 2025-12-15

### Added

- **Nested Recipes**: Introduced `Orchid.Step.NestedStep` to treat entire recipes as atomic steps.
- **Parameter Mapping**: Added `input_map` and `output_map` support in `NestedStep` to rename parameters across boundaries.
- **Global Configuration**: Added `global_hooks_stack` support in `Orchid.run/3` options.
- **Plugin Infrastructure**: Laid the groundwork for plugin integration via standard option injection.

### Changed

- **Option Inheritance**: Improved the option merging strategy (`Orchid.inject_opts_into_recipe`).
    - Hooks are now **stacked** (Parent ++ Child).
    - Executors and other options now follow a **Base + Specific** inheritance rule (Child overrides Parent defaults).

## [0.3.1] - 2025-12-12

### Added

- `:executor_and_opts` options in `Orchid.run/3`