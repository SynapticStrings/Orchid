---
name: elixir-orchid-workflow
description: Orchid Declarative Data Pipeline Architect – complex workflow design & execution with atomic steps, recipes, strategies, hooks, nesting, validation, and fault tolerance.
license: MIT
compatibility: Requires elixir/livebook project
---

# Elixir Orchid Workflow Orchestration

Master the design and execution of complex data processing pipelines using Orchid's declarative workflow engine. This skill encompasses:

- Defining atomic steps with clear I/O contracts
- Composing recipes with automatic dependency resolution
- Selecting execution strategies (serial vs. async)
- Implementing custom hooks for cross-cutting concerns
- Building nested workflows for modular architecture
- Validating recipes statically and debugging at runtime
- Handling errors gracefully with fault-tolerant patterns

## When to Use

### ✅ Good Fit

- **Time-series data processing**: ETL pipelines with multiple transformation stages
- **Multi-stage computations**: ML workflows (data loading → preprocessing → training → evaluation)
- **Microservice orchestration**: Coordinating requests across multiple services
- **Batch processing**: Jobs requiring dependency-aware scheduling
- **Low-latency is NOT critical**: Designed for complex logic, not microsecond timing
- **Modular teams**: Each team owns discrete steps; compose at recipe level

### ❌ Poor Fit

- **Real-time streaming**: Latency-sensitive systems (Kafka, real-time analytics)
- **Single-step workflows**: Use plain Elixir functions instead
- **Synchronous request-response**: HTTP handlers should use standard patterns
- **Highly cyclic logic**: Orchid assumes DAG structure (no loops)

## Getting Started  

Install Orchid in your `mix.exs`:  

```elixir  
defp deps do  
  [  
    {:orchid, "~> 0.5"}  
  ]  
end
```

## Core Instruction Steps

### Phase 1: Define Steps (Atomic Units)

**Goal**: Create reusable, testable processing units with clear contracts.

#### Step 1.1: Choose Step Type

```
IF requirement == "simple synchronous transformation"
  THEN use Module-based Step (use Orchid.Step)
ELSE IF requirement == "lightweight anonymous function"
  THEN use Function Step (2-arity function)
ELSE IF requirement == "complex nested logic"
  THEN use NestedStep with inner recipe
END
```

#### Step 1.2: Define I/O Contract

```
Contract = {InputKeys, OutputKeys}
InputKeys  ∈ {atom, [atom], tuple}
OutputKeys ∈ {atom, [atom], tuple}

Rule: Structure must match run/2 argument pattern
- Single atom input (:data) → receives Param
- List input ([:a, :b]) → receives [Param, Param]
- Tuple input ({:a, :b}) → receives {Param, Param}
```

#### Step 1.3: Implement Logic

```elixir
def run(inputs, opts) do
  # Extract payload
  # Process
  # Wrap in Param.new(name, type, payload, metadata)
  # Return {:ok, result} or {:error, reason}
end
```

#### Step 1.4: Add Validation (Optional)

```elixir
def validate_options(opts) do
  case Keyword.fetch(opts, :required_key) do
    {:ok, _value} -> :ok
    :error -> {:error, "missing :required_key"}
  end
end
```

---

### Phase 2: Compose Recipe (Build DAG)

**Goal**: Define the workflow graph with automatic dependency resolution.

#### Step 2.1: List Steps Out of Order

```elixir
steps = [
  # Order doesn't matter; Orchid sorts topologically
  {Step.Brew, [:powder, :water], :coffee, [style: :latte]},
  {Step.Grind, :beans, :powder},
  {Step.Fetch, :url, :beans}
]
```

#### Step 2.2: Define Initial Params

```elixir
initial_params = [
  Param.new(:url, :string, "https://..."),
  Param.new(:water, :raw, 200)
]
```

#### Step 2.3: Create Recipe

```elixir
recipe = Recipe.new(steps, name: :coffee_workflow)

# Validate statically BEFORE execution
case Recipe.validate_steps(recipe.steps, Enum.map(initial_params, &Map.get(&1, :name))) do
  :ok -> "Safe to execute"
  {:error, reason} -> "Fix: #{inspect(reason)}"
end
```

#### Step 2.4: Understand Validation Rules

```
✓ VALID:
  - All step inputs satisfied by: initial_params OR previous step outputs
  - DAG is acyclic
  - All step options valid

✗ INVALID:
  - Missing input: step needs :foo but nobody provides it
  - Cycle: A→B→C→A
  - Invalid option: step rejects configuration
```

---

### Phase 3: Execute Recipe

**Goal**: Run the workflow with chosen strategy, handling results and errors.

#### Step 3.1: Select Executor

```
Executor Strategy Decision Tree:

IF single_step_or_debugging == true
  THEN use Orchid.Executor.Serial
  ELSE use Orchid.Executor.Async

IF custom_parallelization_logic_needed == true
  THEN implement Orchid.Executor behavior
```

#### Step 3.2: Basic Execution

```elixir
{:ok, results} = Orchid.run(recipe, initial_params)

# OR with custom options:
{:ok, results} = Orchid.run(
  recipe,
  initial_params,
  executor_and_opts: {Orchid.Executor.Serial, []},
  baggage: %{user_id: 123}
)
```

#### Step 3.3: Handle Response Variants

```elixir
# Variant A: Simple results (default)
{:ok, results_map} = Orchid.run(recipe, params)
coffee = results_map[:coffee]

# Variant B: Full response with metadata
{:ok, %Response{payload: result, assigns: metadata}} = 
  Orchid.run(recipe, params, return_response: true)

# Variant C: Error case
{:error, %Orchid.Error{reason: r, step_id: s, kind: k}} = 
  Orchid.run(recipe, params)
```

#### Step 3.4: Propagate Context Deep

```elixir
# Pass baggage to all steps (including nested)
Orchid.run(recipe, params, baggage: %{
  request_id: "abc-123",
  user_role: :admin,
  env: :prod
})

# Inside step, access via:
ctx = Orchid.Runner.Hooks.Core.extract_workflow_ctx(opts)
request_id = Orchid.WorkflowCtx.get_baggage(ctx, :request_id)
```

---

### Phase 4: Handle Execution Errors

**Goal**: Anticipate failures and implement recovery strategies.

#### Step 4.1: Error Types & Causes

```
Type              | Cause                      | Handler
------------------+----------------------------+-----------
:logic            | Step returns {:error, r}   | Validation
:exception        | Unhandled exception        | Rescue
:exit             | Task crash in async mode   | Task.shutdown
:logic_or_exception| Ambiguous               | Log full context

Pre-execution:
:stuck            | Cyclic dependency          | validate_steps/2
:missing_inputs   | Incomplete initial params  | Check recipe
```

#### Step 4.2: Implement Recovery

```elixir
# Pattern A: Fail-fast (default)
case Orchid.run(recipe, params) do
  {:ok, results} -> process(results)
  {:error, error} -> Logger.error("Workflow failed: #{inspect(error)}")
end

# Pattern B: Partial retry
# Use Scheduler.inject_opts to update config at runtime after service restart

# Pattern C: Fallback to secondary recipe
primary_recipe = Recipe.new([...])
secondary_recipe = Recipe.new([...], name: :fallback)

case Orchid.run(primary_recipe, params) do
  {:ok, r} -> r
  {:error, %Error{reason: :external_service_down}} ->
    Logger.warn("Primary failed, trying secondary")
    Orchid.run(secondary_recipe, params)
end
```

#### Step 4.3: Structured Logging

```elixir
:telemetry.attach("orchid-logger", [:orchid, :step, :exception],
  fn event, measurements, meta ->
    Logger.error("Step failed",
      step: meta.impl,
      duration_ms: div(measurements.duration, 1_000_000),
      reason: meta.reason
    )
  end, nil)
```

---

### Phase 5: Inject Hooks (Cross-Cutting Concerns)

**Goal**: Add logging, telemetry, auth checks without modifying step logic.

#### Step 5.1: Understand Hook Stack

```
Execution Flow (Onion Model):

Request
  ↓
[Telemetry Hook]
  ↓
[Global Hooks Stack]
  ↓
[Step-specific Hooks]
  ↓
[Core Hook: execute step]  ← INNERMOST
  ↓
Core Hook returns
  ↓
[Step-specific Hooks] (process result)
  ↓
[Global Hooks Stack] (process result)
  ↓
[Telemetry Hook] (finalize)
  ↓
Response
```

#### Step 5.2: Implement Custom Hook

```elixir
defmodule MyAuthHook do
  @behaviour Orchid.Runner.Hook

  def call(ctx, next) do
    # PRE-EXECUTION: Check permission
    ctx_meta = ctx.step_opts[:__reporter_ctx__] || %{}
    user_role = Orchid.WorkflowCtx.get_baggage(ctx.workflow_ctx, :user_role, :guest)

    # Some steps require admin
    if restricted_step?(ctx.step_implementation) and user_role != :admin do
      {:error, {:unauthorized, ctx.step_implementation}}
    else
      # EXECUTION
      case next.(ctx) do
        {:ok, result} ->
          # POST-SUCCESS
          Logger.info("#{ctx.step_implementation} succeeded for #{user_role}")
          {:ok, result}
        
        {:error, reason} ->
          # POST-FAILURE
          Logger.warn("#{ctx.step_implementation} failed: #{inspect(reason)}")
          {:error, reason}
      end
    end
  end

  defp restricted_step?(impl), do: impl in [StepA, StepB]
end
```

#### Step 5.3: Register Hooks

```elixir
# Global: all steps
Orchid.run(recipe, params, global_hooks_stack: [MyAuthHook, MyMetricsHook])

# Per-step: only specific step
steps = [
  {MyStep, :input, :output, [extra_hooks_stack: [MyAuthHook]]}
]
```

---

### Phase 6: Build Nested Workflows

**Goal**: Treat complex sub-workflows as atomic steps.

#### Step 6.1: Design Modularity

```
Parent Recipe (abstract)
├─ Step A (simple)
├─ NestedStep → SubRecipe1 (complex workflow 1)
│    ├─ Sub-Step A1
│    ├─ Sub-Step A2
│    └─ Sub-Step A3
└─ NestedStep → SubRecipe2 (complex workflow 2)
     ├─ Sub-Step B1
     └─ Sub-Step B2
```

#### Step 6.2: Create Sub-Recipe

```elixir
sub_recipe = Recipe.new([
  {SubStepA1, :input, :intermediate},
  {SubStepA2, :intermediate, :output}
], name: :data_pipeline)
```

#### Step 6.3: Compose with NestedStep

```elixir
parent_recipe = Recipe.new([
  # Step before nested
  {FetchStep, :url, :raw_data},
  
  # Nested: wrap sub_recipe as atomic step
  {Orchid.Step.NestedStep,
    :raw_data,                    # Parent input name
    :processed_data,              # Parent output name
    [
      recipe: sub_recipe,
      # OPTIONAL: Rename inputs for sub-recipe
      input_map: %{raw_data: :input},      # Parent :raw_data → Sub :input
      # OPTIONAL: Rename sub-recipe outputs back
      output_map: %{output: :processed_data}  # Sub :output → Parent :processed_data
    ]
  },
  
  # Step after nested
  {SaveStep, :processed_data, :saved}
])
```

#### Step 6.4: Propagate Context to Nested Steps

```elixir
# Context automatically flows down via workflow_ctx

# Inside nested step run/2, extract it:
def run(input, opts) do
  ctx = Orchid.Runner.Hooks.Core.extract_workflow_ctx(opts)
  request_id = Orchid.WorkflowCtx.get_baggage(ctx, :request_id)
  # Now request_id is available in nested sub-steps too
end
```

---

### Phase 7: Validate & Debug

**Goal**: Ensure recipe correctness before runtime; diagnose failures quickly.

#### Step 7.1: Static Validation Checklist

```elixir
def validate_recipe(recipe, initial_params) do
  initial_keys = Enum.map(initial_params, &Map.get(&1, :name))
  
  # Check 1: Basic structure
  IO.inspect(recipe.steps, label: "Steps")
  
  # Check 2: Validation
  case Orchid.Recipe.validate_steps(recipe.steps, initial_keys) do
    :ok -> IO.puts("✓ No missing inputs, no cycles")
    {:error, {:missing_inputs, m}} -> IO.inspect(m, label: "✗ Missing")
    {:error, {:cyclic, c}} -> IO.inspect(c, label: "✗ Cycles")
    {:error, other} -> IO.inspect(other, label: "✗ Other error")
  end
  
  # Check 3: Option validation
  Enum.each(recipe.steps, fn step ->
    {impl, _, _, opts} = Orchid.Step.ensure_full_step(step)
    if function_exported?(impl, :validate_options, 1) do
      case impl.validate_options(opts) do
        :ok -> IO.puts("✓ #{impl} options valid")
        {:error, e} -> IO.puts("✗ #{impl}: #{inspect(e)}")
      end
    end
  end)
end
```

#### Step 7.2: Runtime Debugging

```elixir
# Enable all telemetry events
:telemetry.attach_many("debug", [
  [:orchid, :step, :start],
  [:orchid, :step, :done],
  [:orchid, :step, :exception],
  [:orchid, :step, :progress]
], fn event, measurements, meta ->
  IO.inspect({event, measurements, meta}, label: "ORCHID")
end, nil)

# Use Serial executor for deterministic stepping
{:ok, results} = Orchid.run(recipe, params,
  executor_and_opts: {Orchid.Executor.Serial, []}
)
```

#### Step 7.3: Error Diagnosis

```elixir
case Orchid.run(recipe, params) do
  {:error, %Orchid.Error{
    reason: reason,
    step_id: step_id,
    context: ctx,
    kind: kind
  }} ->
    IO.puts("""
    Workflow Failed:
      Step: #{inspect(step_id)}
      Kind: #{kind}
      Reason: #{inspect(reason)}
      
    Execution History:
    """)
    
    Enum.each(ctx.history, fn {step, keys} ->
      {impl, _, _} = Orchid.Step.extract_schema(step)
      IO.puts("  ✓ #{impl} → #{inspect(keys)}")
    end)
    
    IO.puts("\nPending Steps:")
    Enum.each(ctx.pending_steps, fn {step, idx} ->
      {impl, in_k, _} = Orchid.Step.extract_schema(step)
      IO.puts("  ⏳ [#{idx}] #{impl} (needs: #{inspect(in_k)})")
    end)
    
    IO.puts("\nAvailable Keys: #{inspect(MapSet.to_list(ctx.available_keys))}")
end
```

## Decision Logic

### ExecutorSelection Algorithm

```
INPUT: recipe, execution_context
OUTPUT: executor_module, executor_options

ALGORITHM ExecutorSelect:
  IF is_debugging OR recipe_size < 3 THEN
    RETURN {Orchid.Executor.Serial, []}
  END
  
  independent_steps ← count_steps_with_no_dependencies(recipe)
  IF independent_steps < 2 THEN
    RETURN {Orchid.Executor.Serial, []}
  END
  
  available_cores ← System.schedulers_online()
  estimated_overhead ← recipe_size * 100  // μs
  
  IF estimated_overhead < execution_timeout THEN
    max_concurrency ← min(available_cores, independent_steps)
    RETURN {Orchid.Executor.Async, [concurrency: max_concurrency]}
  ELSE
    RETURN {Orchid.Executor.Serial, []}
  END
END
```

### DependencyResolution Algorithm

```
INPUT: steps, initial_keys
OUTPUT: {:ok, topological_order} OR {:error, reason}

ALGORITHM ResolveDependencies (Kahn's Algorithm):
  available_keys ← initial_keys
  pending ← copy(steps)
  resolved ← []
  
  WHILE pending is not empty DO
    ready ← filter(pending, lambda s: dependencies(s) ⊆ available_keys)
    
    IF ready is empty AND pending is not empty THEN
      IF cycle_exists(pending) THEN
        RETURN {:error, {:cyclic, pending}}
      ELSE
        RETURN {:error, {:missing_inputs, pending}}
      END
    END
    
    FOR each step IN ready DO
      resolved.append(step)
      pending.remove(step)
      available_keys.union(outputs(step))
    END
  END
  
  RETURN {:ok, resolved}
END
```

### ExecutorSelection

See [executor_selection.md](references/decision_logic/executor_selection.md).

### HookOrderingDecision

```
DECISION: How to order hooks in the stack?

RULE 1: Telemetry Hook
  POSITION: Always outermost
  REASON: Must measure total execution time including other hooks

RULE 2: Global Hooks
  POSITION: After Telemetry, before step-specific
  REASON: Shared concerns (auth, logging) for all steps

RULE 3: Step-Specific Hooks
  POSITION: After global, before Core
  REASON: Step customizations override global behavior

RULE 4: Core Hook
  POSITION: Always innermost
  REASON: Must be last before step execution

EXAMPLE ORDER:
[Telemetry] → [GlobalAuth, GlobalMetrics] → [StepCache] → [Core]
```

See [hook_ordering.md](references/decision_logic/hook_ordering.md) for more infomation.

### ErrorHandlingStrategy

```
DECISION TREE: What action to take on step failure?

INPUT: error_kind, is_recoverable, retry_budget

IF error_kind == :logic THEN
  // Step returned {:error, _}
  IF is_recoverable(error) AND retry_budget > 0 THEN
    ACTION: Mark step unrunning, decrement retry_budget, re-queue
  ELSE
    ACTION: Fail workflow immediately, return error context
  END

ELSE IF error_kind == :exception THEN
  // Unhandled exception in step
  IF error == {:service_down, service_id} THEN
    ACTION: Check if alternative recipe exists, switch
  ELSE
    ACTION: Fail workflow, propagate exception
  END

ELSE IF error_kind == :exit THEN
  // Task process crashed (async mode)
  ACTION: Cleanup remaining tasks, fail workflow with reason

ELSE IF error_kind == :logic_or_exception THEN
  // Ambiguous, log fully and fail
  ACTION: Include full context in error response
END
```

---

## Common Patterns

### Pattern A: Data Transformation Pipeline

```elixir
Recipe.new([
  {FetchData, :url, :raw},
  {Parse, :raw, :structured},
  {Validate, :structured, :valid},
  {Transform, :valid, :final}
])
```

### Pattern B: Parallel Independent Steps

```elixir
Recipe.new([
  {FetchA, :input, :data_a},
  {FetchB, :input, :data_b},    # Independent
  {Combine, [:data_a, :data_b], :merged}  # Merge when both ready
])
```

### Pattern C: Error Recovery with Fallback

```elixir
primary_recipe = Recipe.new([...], name: :primary)
fallback_recipe = Recipe.new([...], name: :fallback)

case Orchid.run(primary_recipe, params) do
  {:ok, r} -> r
  {:error, error} when is_recoverable(error) ->
    Logger.warn("Primary failed, using fallback")
    Orchid.run(fallback_recipe, params)
  {:error, error} ->
    {:error, error}
end
```

### Pattern D: Context-Aware Steps

```elixir
steps = [
  {FetchUser, :user_id, :user, [extra_hooks_stack: [AuthCheckHook]]},
  {ProcessData, [:user, :raw_data], :result}
]

Orchid.run(Recipe.new(steps), params, 
  baggage: %{request_id: "abc", user_role: :admin})
```

---

## Troubleshooting

| Symptom | Diagnosis | Fix |
|---------|-----------|-----|
| `{:error, {:missing_inputs, map}}` | Step needs param nobody provides | Add to initial_params or ensure prior step outputs it |
| `{:error, {:cyclic, steps}}` | A→B→A dependency loop | Redesign: remove dependency, split into separate recipes |
| Step never runs | Dependency stuck on unavailable param | Check: previous step output key matches what current step expects |
| Serial executor slow but Async not faster | Serialization overhead > parallelism benefit | Keep Serial, or reduce steps count |
| Hook not executing | Wrong registration method | Use `extra_hooks_stack` for per-step, `global_hooks_stack` for all |
| Nested step context missing | Baggage not propagating | Check: `extract_workflow_ctx(opts)` and context depth |
