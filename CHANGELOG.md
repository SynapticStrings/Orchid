# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.0.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [0.6.2] - 2026-07-07

### Updated

- **README**: Added introduction with related packages.

## [0.6.1] - 2026-03-30

### Added

- **Orchid.Repo**: Added a helper funtion `Orchid.Repo.dispatch_store/3`.

### Changed

- **Type Annotation**: Move `t:Orchid.Param.ref_payload/0`'s second item into `{module, ref}`.

## [0.6.0] - 2026-03-29
  
### Breaking Changes  
  
- **Orchid.Repo**: Refactored storage behaviour. Callbacks now accept a `store_ref` as the first argument to support multiple store instances.  
- **Operon.Request**: Fixed typo in struct field `:inital_params`, renamed to `:initial_params`. Code manually constructing this struct needs to be updated.  
  
### Added  
  
- **Orchid.Repo**: Added optional extension behaviours: `Deletable`, `ContentAddressable`, `GC`, `Transferable`.  
  
### Fixed  
  
- Correct key name in ` Orchid.Operon.Request` from `:inital_params` to `initial_params`.  

## [0.5.8] - 2026-03-27

### Fixed

- **Monokey with List**: Now monokey like `["simple_key"]` may not cause `{:error, :stuck}`.

## [0.5.7] - 2026-03-26

### Added

- **Binary Step IO Key**: Now Orchid can resolve binary keys!

### Documentation

- **Release Data**: Correct release date from 2025 into 2026.

## [0.5.6] - 2026-02-12

### Changed

- **Core Hook**: Enhanced `align_output_names/2` logic in `Orchid.Runner.Hooks.Core`. The runner now automatically renames the returned `Param` struct to match the output key defined in the Recipe. This improvement ensures smoother data flow, especially for **Implicit Mapping** in Nested Steps, allowing inner steps to be reused more flexibly without manual renaming.

#### Documentation

- **Refactor**: Major update to `README.md`.
    - Added detailed sections and examples for **Nested Steps** (covering both Implicit and Explicit mapping).
    - Clarified usage of **Executors** (Serial vs. Async).
    - Expanded explanations for **Layered Hooks** and **Pipeline Middleware (Operons)**.
- **Fixes**: Corrected multiple typos (e.g., `Definate` -> `Define`, `mannual` -> `manual`) throughout the documentation and code comments.

## [0.5.5] - 2026-02-11

### Added

- **Telemetry Hook**: Add `Orchid.Runner.Hooks.Telemetry.error_handler/4` to facilitate debugging.

### Fixed

- **Async Executor**: Fixed an issue where cleaning up other steps failed when one step in an Async Executor threw an error.

## [0.5.4] - 2026-02-02

### Added

- Support for Steps returning a Map `%{key => param}` directly.
- `Orchid.Recipe`: Support `{:ok, opts}` return value in `validate_options/1` callback (friendly to NimbleOptions).

### Fixed

- **Single Step Runner**: Fixed a bug where returning multiple params in a Step list could lead to incorrect output mapping.
- **Single Step Runner**: Now raises `ArgumentError` when a Step returns multiple params but none match the requested output key name (preventing ambiguity).

## [0.5.3] - 2026-01-23

This release improves the developer experience with syntactic sugar for workflow execution, reorganizes documentation for better readability, and significantly boosts test coverage.

### Added

- **Execution Sugar**: `Orchid.run/3` now accepts a raw list of steps (`[Step.t()]`). It automatically wraps them into a `Recipe` internally, reducing boilerplate for simple scripts or tests.
- **Single Param Input**: `Orchid.Scheduler.build/3` now accepts a single `Orchid.Param` struct as `initial_params`, automatically wrapping it into the required map structure.
- **CI/CD**: Integrated Codecov for test coverage reporting.

### Documentation

- **Module Grouping**: Configured `groups_for_modules` in `mix.exs`. HexDocs are now organized into logical categories (Dataflow Declaration, Orchestration, Executors, etc.) instead of a flat list.
- **Moduledocs**: Added missing documentation for `Orchid.Executor.Async`, `Orchid.Param`, and `Orchid.Operon.Execute`.
- **Badges**: Added Hex.pm, License, and Codecov badges to `README.md`.

### Changed

- **Internal Safety**: In `Orchid.Recipe`, strict key fetching (`Keyword.fetch!`) is now used when updating inner recipes for `NestedStep`, ensuring configuration errors are caught early.

## [0.5.2] - 2026-01-17

> **Robustness & Cleanup**.
> This release focuses on standardizing return types, fixing edge cases in asynchronous execution, and cleaning up internal identifiers to be less dependent on list indices.

### Fixed

- **Async Executor**: Fixed an issue where `Orchid.Executor.Async` would discard the context payload when a step returned `{:special, context}`. It now correctly wraps the payload in the error reason `{:core_executor_not_support_special, context}`.
- **Pipeline Consistency**: `Orchid.Pipeline.run/2` now consistently returns an `Orchid.Operon.Response` struct (wrapping the error) even when the middleware stack is empty or hits the sink, preventing format mismatch errors.

### Added

- **Custom Core Hook**: Added `:core_hook` support in `Orchid.WorkflowCtx` config. This allows replacing `Orchid.Runner.Hooks.Core` with a custom module, which is useful for specialized execution strategies or testing mocks.
- **Step Comparison**: Added `Orchid.Step.ID.same?/2` to check if two steps share the same Input/Output interface.

### Changed

- **Recipe Validation**: `Orchid.Recipe.validate_steps/2` no longer includes the step index (`idx`) in `{:invalid_step_option, ...}` errors. This aligns with the roadmap goal of moving away from order-based identification.
- **Internal ID Logic**: Refactored `Orchid.Step.ID.finger_print/2`. The `as_num?` option is replaced by `headless?`. It no longer returns an integer hash but simpler tuples (`{in, out}` or `{impl, in, out}`), making it more predictable for debugging.
- **Context API**: Renamed Orchid.WorkflowCtx's `add_step/2` to `add_depth/2` to better reflect its purpose of tracking call stack depth in nested workflows.

## [0.5.1] - 2026-01-04

> **Documentation & Refactoring**.
> This release polishes the internal architecture, making the `WorkflowCtx` the single source of truth for configuration, and significantly improves internal documentation.

### Changed

- **Configuration Source of Truth**: `Orchid.run/3` now initializes `WorkflowCtx` earlier. Consequently, `Orchid.Operon.Request` no longer carries `executor_and_opts` directly; it is now dynamically resolved from `WorkflowCtx`. This allows Operons to swap Executors dynamically (e.g., switching to a GPU-optimized executor based on input).
- **Scheduler Internals**:
  - Reordered fields in `Orchid.Scheduler.Context` for better memory alignment (maybe).
  - **Docs**: Added detailed explanation on why Orchid uses a mix of `List` (for deterministic order) and `MapSet` (for O(1) lookups) in the Scheduler context.
- **Code Generation**: `Orchid.Runner` now uses `apply/3` to invoke step implementations. This reduces compile-time dependency warnings when creating dynamic workflows.

### Fixed

- **Execution History**: Fixed an inconsistency in `Scheduler.merge_result/3` where execution history tracking was slightly malformed (removed the index from history tuples).
- **Typing**: Relaxed type specs for `telemetry_meta` and `assigns` in `Runner` to generic `map()` to accommodate more flexible plugin data.

## [0.5.0] - 2026-01-02

> _Happy New Year!_

This is the first release of the year, bringing a new plugin architecture to Orchid. May your workflows bloom beautifully this year!

### Breaking Changes

- **Nested Step Error Handling**: `Orchid.Step.NestedStep` now returns `{:error, {:nested_step_execution_failed, inner_context}}` instead of just the reason. This allows parent workflows to access the failed child's context for potential recovery or debugging.
- **Hook Protocol**: The `Orchid.Runner.Hook` behavior now supports a third return type: `{:special, any()}`. Custom hooks implementing stricter type checks may need updates.
- **Default Executors**: The built-in `Serial` and `Async` executors will now explicitly error with `{:core_executor_not_support_special, ...}` if a step returns a `{:special, ...}` tuple. This signals that a specialized executor (e.g., from a Session plugin) is required to handle such states.

### Added

- **Plugin Support (Special Return)**: Introduced `{:special, payload}` as a first-class return type in `Orchid.Runner`. This mechanism is designed for plugins (like `Orchid.Session`) to implement flow control logic like **Pause**, **Interrupt**, or **Yield** without abusing the Error channel.
- **Telemetry**: Added a new event `[:orchid, :step, :special]` to track steps that exit with the special status.
- **Error Kinds**: Added `:logic_or_exception` to `Orchid.Error` kinds to better describe failures caught in async tasks.

### Changed

- **Async Executor**: Improved robustness by explicitly flushing the monitor message (`:DOWN`) when a task completes successfully, preventing potential race conditions or mailbox pollution.
- **Dependencies**: Updated `lib/orchid/step/id.ex` to depend on `Orchid.Step` alias correctly.
- **Documentation**: Updated README roadmap and translated more comments in `Async` executor to English.
- **Copyright**: Updated License year to 2026.

### Internal

- **Refactoring**: `Orchid.WorkflowCtx` now uses pipeline operators for cleaner config/baggage merging logic.

## [0.4.1] - 2025-12-27

### Refinements (Improvements to 0.4.0)

- **Context Propagation**: Introduced "Baggage" to `Orchid.WorkflowCtx`. You can now pass global metadata via `Orchid.run(..., baggage: map)` which propagates vertically into nested steps.
- **Hooks Resolution**: Global hooks are now correctly resolved from the `WorkflowCtx` configuration instead of the recipe options. This aligns the behavior with the new Context architecture introduced in 0.4.0.
- **Error Reporting**: The cyclic dependency error now returns useful `Step` structs (`{:cyclic, steps}`) instead of opaque indices.

### Fixed

- **Validation**: Fixed a variable scope issue in `Recipe.validate_steps` that could cause a crash during cycle detection.
- **Key Normalization**: Moved IO key normalization logic to `Orchid.Step.ID` to fix potential inconsistencies between static checks and runtime execution.
- **Telemetry**: Fixed the injection timing of `__reporter_ctx__` to ensuring metadata is available during the entire step lifecycle.

### Docs

- **Internals**: Added comprehensive documentation for `Orchid.Error`, `Orchid.Scheduler.Context`, and `Orchid.WorkflowCtx`.
- **Tests**: Translated integration test comments to English.

## [0.4.0] - 2025-12-26

### Breaking Changes

- **Context & Options**: `Orchid.run/3` now strictly filters input options. Arbitrary keys are no longer implicitly merged into step options. User-defined metadata/context must now be passed via the new `:baggage` option.
- **Error Handling**: Execution failures are now returned as `{:error, %Orchid.Error{}}`. The `Orchid.Error` struct (an Exception) contains the failure reason, the step fingerprint, the failure kind (`:logic`, `:exception`, `:exit`), and the **execution context** (enabling partial result recovery).
- **Telemetry**: Renamed the event `[:orchid, :step, :stop]` to `[:orchid, :step, :done]` to distinct completion from termination.
- **Step DSL**: The `nested?/0` callback has been replaced by the module attribute `@orchid_step_nested boolean` when using `Orchid.Step`.
- **Plugin**: Removed `Orchid.Plugin` module as it was unused and superseded by the Operon/Hook architecture.

### Added

- **Workflow Context**: Introduced `Orchid.WorkflowCtx` to explicitly manage execution scope, nested paths, configuration, and baggage throughout the pipeline.
- **API**: Added `Orchid.run_with_ctx/3` to support executing recipes with a pre-initialized context (e.g., for sub-workflows or resuming).
- **Identification**: Introduced `Orchid.Step.ID` to generate deterministic fingerprints/IDs for steps.
- **Helpers**: Added `Orchid.Step.report/3` to standardize progress reporting via Telemetry.

### Changed

- **Executor**: Executors (`Async` and `Serial`) now capture the runtime context upon failure and wrap it in `Orchid.Error`, preventing data loss during crashes.
- **Internals**: Refactored `Orchid.Runner` to propagate `WorkflowCtx` instead of loose keyword lists.

## [0.3.5] - 2025-12-23

### Changed

- **Executor**: Refined the return signature of `Orchid.Executor.execute_next_step/1`. It now returns `{:cont, context}` for successful step execution, providing a clearer distinction between running, stuck, and done states.
- **API Visibility**: Changed Orchid.inject_opts_into_recipe/2 from public (`def`) to private (`defp`) to reduce the public API surface area.
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