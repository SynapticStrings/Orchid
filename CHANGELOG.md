# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.3] - 2025-12-18

### Fixed

- **Scheduler**: Fixed a potential crash in executor caused by invoking a scheduler function signature,`mark_running/2`.
- **Dialyzer**: Resolved opaque type warnings related to `Scheduler.build/2` by adding explicit ignore rules.

### Changed

- **Error Handling**: Renamed the error tag in `NestedStep` from `:nested_execution_failed` to `:nested_step_execution_failed` for better clarity.
- **Internal API**: Renamed `step_default_opts` to `step_opts` within `Orchid.Runner.Context` to better reflect that these are the final merged options.
- **Refactoring**: Consolidated `Orchid.Scheduler.Context` definition back into `lib/orchid/scheduler.ex` to improve module cohesion and reduce file fragmentation.
- **Custome Executor**:  Changed `mark_running/2` into `mark_running_steps/3` to allow pushing running steps when retry.
- **Code Style**: Unified codebase to use single-line function definitions (`def ..., do: ...`) for consistency.

### Documentation

- **Internationalization**: Enhanced `README.md` and translated core module docstrings (Executor, Async, Serial) from Chinese to English.
- **Architecture**: Updated architecture diagrams in `README.md` to reflect the current data flow more accurately.

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