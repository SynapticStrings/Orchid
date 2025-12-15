# Roadmap

## Core/Facade

- [x] Declarative steps
- [x] Flow orchestration
- [x] Nested recipes
- [x] Executor protocol and implementations
- [x] Hooks
- [o] Pre-run modifications
  - [x] Step configuration (via `Orchid.Recipe.assign_options/3`)
  - [x] Recipe configuration
  - [o] Operon stack modification (via configuration changes)
  - [o] Internal hook stack modification for steps (can be done by modifying step configuration)
- [x] Pre-run checks(`Orchid.Scheduler.build/2`)
  - [x] Missing Recipe check
  - [x] Recipe cycle check
  - [x] Step option check (implemented at the step level)
- [o] Runtime modifications
  - *Only for steps not yet executed*
  - [x] step configuration(`Orchid.Scheduler.inject_opts/3`)
  - ~~Executor configuration~~ (Depends on specific executor implementation; considering Orchid's goal of staying lean and the fact that Operon can achieve similar effects, this is abandoned)
  - [o] Recipe configuration (`Recipe.walk/3`'s `:inner_recipe` mode + custom function)
  - [o] Runner hooks (essentially still step configuration)

## Documents

- [ ] API consolidation
  - [x] Organize logic
    - Decouple relationships between Scheduler, Execute operon, and specific Executor implementations
    - Document key context
  - [x] Write documentation & Publish to <hex.pm>
    - use English
  - [ ] finish document
    - Chinese first, translate into English
  - [ ] 100% coverage

## Advanced Featrues

*Focusing on stability, scalability, and ecosystem integration.*

### Serialization Protocol (Context Marshalling)

* **Goal**: Ensure the `Context` and `Recipe` are fully serializable (free of runtime closures/PIDs).
* **Impact**: Prerequisites for persistence, clustering, and debugging tools.

### Resilient Executor & Resource Management

* **Goal**: Evolving `Executor` to handle external failures (e.g., AI inference service restarts) and internal concurrency limits.
* **Key Aspect**: 
    * Isolate resource lifecycle management (Supervision strategy).
    * Back-pressure mechanism (prevent overloading downstream GPU/Resources).

### Persistence & Breakpoint Resume

* **Goal**: Save execution state to external storage (Disk/DB).
* **Prerequisite**: Implement `Orchid.Repo` behavoir.
* **Impact**: Allow workflows to recover from crashes or system restarts without re-running completed expensive steps (crucial for long-running AI tasks).

### Dynamic Workflow Mutation (Experimental)

* **Goal**: Allow modifying the dependency graph (DAG) during runtime or just before execution.
* **Note**: *To be evaluated. Complex scenarios might be solvable via `Hooks` or `Operons` without introducing graph mutability.*
