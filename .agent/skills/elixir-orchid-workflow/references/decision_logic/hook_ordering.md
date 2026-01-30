# Hook Ordering & Composition

## The Hook Stack Model

Hooks form an "onion" where execution flows through all hooks before reaching core:

```
REQUEST
  ↓
┌─────────────────────────┐
│  Hook 1 (outermost)     │ PRE-execution
├─────────────────────────┤
│  Hook 2                 │ PRE-execution
├─────────────────────────┤
│  Hook 3                 │ PRE-execution
├─────────────────────────┤
│  *** CORE EXECUTION *** │ ← Step runs here
├─────────────────────────┤
│  Hook 3                 │ POST-execution
├─────────────────────────┤
│  Hook 2                 │ POST-execution
├─────────────────────────┤
│  Hook 1 (outermost)     │ POST-execution
└─────────────────────────┘
  ↓
RESULT
```

## Canonical Ordering

The `Orchid.Runner` builds this stack automatically:

```elixir
hook_stack = [
  Orchid.Runner.Hooks.Telemetry,    # Outermost: measure time
  ...WorkflowCtx.global_hooks...,   # Shared concerns
  ...step_opts.extra_hooks...,      # Step-specific
  WorkflowCtx.core_hook             # Innermost: execute
]

# Execute via: run_pipeline(hook_stack, ctx)
```

## Guidelines

### Telemetry Hook

- **Position**: Always first in stack (outermost)
- **Reason**: Measures total time, including other hooks
- **Emits**: `:start`, `:done`, `:exception` events
- **Must not be overridden** unless you have specific metrics needs

### Global Hooks (Shared)

- **Position**: After Telemetry, before step-specific
- **Reason**: Applied to ALL steps
- **Examples**: Auth, logging, metrics aggregation
- **Ordering within**: Early hooks block later ones, so put guards first:
  ```
  [AuthCheckHook, LoggingHook, MetricsHook, RateLimitHook]
     ↑                                             ↑
   Deny fast                                 Allow with cost
  ```

### Step-Specific Hooks

- **Position**: After global, before Core
- **Reason**: Override global behavior for specific step
- **Use**: Cache, performance tricks, step-specific auth
- **Example**:
  ```elixir
  {MyStep, :input, :output, [
    extra_hooks_stack: [
      CacheHook,      # Check cache first
      RateLimitHook   # Then rate limit
    ]
  ]}
  ```

### Core Hook

- **Position**: Always last (innermost)
- **Reason**: Must be closest to actual step execution
- **Default**: `Orchid.Runner.Hooks.Core`
- **Override**: Only if you need custom run/2 semantics

## Common Patterns

### Pattern A: Auth → Logging → Execute

```elixir
global_hooks_stack: [
  AuthHook,         # Fail fast if not allowed
  LoggingHook,      # Only log if auth passed
  MetricsHook       # Track allowed executions
]
```

### Pattern B: Cache → Rate Limit → Auth → Execute

```elixir
extra_hooks_stack: [
  CacheHook,        # Return fast if cached
  RateLimitHook,    # Then check rate
  AuthHook,         # Then auth
  # Core comes next
]
```

### Pattern C: Distributed Tracing

```elixir
defmodule TracingHook do
  @behaviour Orchid.Runner.Hook
  
  def call(ctx, next) do
    span_id = UUID.uuid4()
    ctx = put_in(ctx.workflow_ctx, [:baggage, :span_id], span_id)
    
    IO.puts("SPAN_START #{span_id}")
    result = next.(ctx)
    IO.puts("SPAN_END #{span_id}")
    
    result
  end
end

# Use:
global_hooks_stack: [TracingHook, OtherHooks...]
```

## Anti-Patterns

❌ **Slow guard in wrong position**

```elixir
# BAD: Database lookup before cache
[DatabaseHook, CacheHook]

# GOOD: Fast checks first
[CacheHook, DatabaseHook]
```

❌ **Nested hook stacks**

```elixir
# BAD: Hooks within hooks → confusing flow
global_hooks_stack: [
  SomeHook.with_nested([OtherHook])
]

# GOOD: Flat list
global_hooks_stack: [SomeHook, OtherHook]
```

❌ **Modifying ctx incorrectly**

```elixir
# BAD: Create new ctx, losing updates
def call(ctx, next) do
  new_ctx = %Orchid.Runner.Context{step_implementation: ctx.step_implementation}
  next.(new_ctx)
end

# GOOD: Merge changes into ctx
def call(ctx, next) do
  updated_ctx = %{ctx | step_implementation: new_impl}
  next.(updated_ctx)
end
```