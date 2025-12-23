# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.3.5] - 2025-12-23

### Changed

- **Executor**: Refined the return signature of `Orchid.Executor.execute_next_step/1`. It now returns `{:cont, context}` for successful step execution, providing a clearer distinction between running, stuck, and done states.
- **API Visibility**: Changed `Orchid.inject_opts_into_recipe/2` from public (`def`) to private (`defp`) to reduce the public API surface area.
- **Structs**: initialized default values for `Orchid.Operon.Request`. `assigns` now defaults to `%{}` (was nil) and `operon_options` to `[]`.
- **Packaging**: Included `CHANGELOG.md` in the Hex package definition and documentation extras in `mix.exs`.

### Fixed

- **Types**: Added missing type specifications for `Orchid.Pipeline.run/2` and corrected the spec for `Orchid.Recipe.assign_options/3`.

### Documentation

- **Roadmap**: Updated `README.md` to reflect plans for `OrchidInstruments` and `OrchidPersistence`.

## [0.3.4] - 2025-12-22

### Added

- **Executor**: Added `Orchid.Executor.execute_next_step/1`. This helper encapsulates logic for fetching the next ready step and detecting "stuck" or "done" states, simplifying custom Executor implementation and debugging.
- **Recipe**: Enhanced `Orchid.Recipe.assign_options/3`. It now accepts a transformation function `(Step.t() -> Step.t())` as the third argument, allowing dynamic modification of step configurations.
- **Runner**: Updated `Orchid.Runner.run/4`. Added an optional `initial_assigns` argument to inject context assigns when running individual steps.

### Changed
- **Executor.Serial**: Refactored the internal loop to utilize the new `execute_next_step/1` helper.
- **Scheduler**: Updated the internal structure of `Context.history`. It now records `{Step.t(), step_index, MapSet<ProducedKeys>}` to track keys produced by each step more accurately.
- **Mix**: Configured `elixirc_paths` in `mix.exs`. Files in `test/support` are now automatically compiled only in the `:test` environment, removing the need for manual requires in `test_helper.exs`.

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