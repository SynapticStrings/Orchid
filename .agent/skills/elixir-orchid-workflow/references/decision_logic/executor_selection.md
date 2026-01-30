# Executor Selection Decision Logic

## Quick Reference

| Scenario | Executor | Config |
|----------|----------|--------|
| **Learning / Debugging** | Serial | None |
| **Single step or linear chain** | Serial | None |
| **2-10 independent parallel steps** | Async | `[concurrency: 4]` |
| **10+ independent steps** | Async | `[concurrency: System.schedulers_online()]` |
| **Custom parallelization needs** | Custom | Implement behavior |

## Decision Tree

```
START

Q1: Are you debugging?
  YES → Use Serial (deterministic step-by-step)
  NO  → Go to Q2

Q2: Does recipe have ≥2 independent steps?
  NO  → Use Serial (no parallelism benefit)
  YES → Go to Q3

Q3: Is total execution time < 100ms?
  YES → Use Serial (overhead > benefit)
  NO  → Go to Q4

Q4: Do you need custom resource management?
  YES → Implement custom Executor
  NO  → Use Async

Q5: How many parallel slots available?
  cores = System.schedulers_online()
  concurrency = min(cores, independent_step_count)
  Use Async with [concurrency: concurrency]

END
```

## Overhead Analysis

### When Serial is Better

- Recipe: 1-2 steps (no parallelism gain)
- Steps are fast (<10ms) and sequential
- Context switching overhead > parallelism benefit
- Total execution < 50ms

### When Async is Better

- Recipe: 3+ steps with parallelizable branches
- Independent steps collectively take >100ms
- 2+ CPU cores available
- Steps have blocking I/O (network, database)

### Custom Executor When

- Need fine-grained backpressure control
- Steps have different priority levels
- Need custom failure handling (e.g., circuit breaker)
- Advanced resource constraints (memory, I/O quota)