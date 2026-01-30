# Orchid Glossary

## Core Concepts

### Step

An atomic unit of work. Receives input parameters, processes them, returns output.

- **Variants**: Module step (`use Orchid.Step`), Function step (2-arity fn), Nested step
- **Contract**: `{InputKeys, OutputKeys}` defines what it consumes and produces

### Recipe

A collection of steps forming a DAG (Directed Acyclic Graph).

- **Role**: Definition layer; not execution state
- **Properties**: Name, steps list, options

### Param

Standard unit of data exchange between steps.

- **Fields**: `name`, `type`, `payload`, `metadata`
- **Why**: Ensures consistent data flow, type safety, metadata tracking

### Dependency

Step A depends on Step B if A's input keys include B's output keys.

- **Resolution**: Topological sort (like Kahn's algorithm)
- **Detection**: Cycle detection before execution

### Executor

Strategy for running steps.

- **Serial**: One step at a time (debugging)
- **Async**: Parallel independent steps (performance)
- **Custom**: Your own scheduling logic

### Hook

Middleware that wraps step execution (pre/post logic).

- **Examples**: Auth, logging, metrics, caching
- **Stack**: Onion model (outer → inner → outer)

### NestedStep

A step whose implementation IS another Recipe.

- **Purpose**: Modular sub-workflows
- **I/O Mapping**: Optional renaming of inputs/outputs

### Scheduler Context

Execution state: pending steps, available params, running tasks.

- **Role**: Tracks progress of Recipe execution

### WorkflowCtx

Global context available to all steps.

- **Contents**: Config, baggage (custom data), execution path depth
- **Use**: Share data across steps (request ID, user role, etc.)

## Common Operations

### Validate

Check Recipe before execution:

- Options are valid
- All inputs satisfied
- No cycles exist

### Run

Execute Recipe:

- Build execution state
- Select executor
- Return results or error

### Report

Step sends progress update via telemetry:
- Useful for long-running steps
- Accessible via telemetry listeners

### Inject Options

Dynamically modify step config at runtime.
- Global: apply to all matching steps
- Per-step: in step definition

## Error Types

| Kind | Cause | Recovery |
|------|-------|----------|
| `:logic` | Step returned `{:error, r}` | Depends on `r` |
| `:exception` | Unhandled exception | Inspect stacktrace |
| `:exit` | Process died (async) | Check resource limits |
| `:logic_or_exception` | Ambiguous | Log fully |

## Telemetry Events

```
[:orchid, :step, :start]
  → emitted at step start
  → meta: {impl, in_keys, out_keys}

[:orchid, :step, :done]
  → emitted on success
  → measurements: {duration}

[:orchid, :step, :exception]
  → emitted on failure
  → meta: {reason, kind}

[:orchid, :step, :progress]
  → optional, emitted by step via report/2
  → meta: {progress, payload}
```