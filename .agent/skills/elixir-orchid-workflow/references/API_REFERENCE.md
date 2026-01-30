# Orchid API Reference

## Top-Level API

### `Orchid.run(recipe_or_steps, initial_params, opts \\ [])`
Execute a workflow.

**Args:**
- `recipe_or_steps`: `Recipe` or list of `Step`
- `initial_params`: `[Param]` or `%{key => Param}`
- `opts`: keyword

**Options:**
- `:executor_and_opts`: `{module, keyword}` executor to use
- `:global_hooks_stack`: `[module]` hooks for all steps
- `:operons_stack`: `[module]` request-level middleware
- `:return_response`: boolean, return `Response` struct instead of payload
- `:baggage`: map, custom data to all steps

**Returns:**
- `{:ok, %{key => Param}}` on success
- `{:error, Error}` on failure

---

## Step Definition

### `defmodule MyStep do use Orchid.Step`
Declares a step.

**Callbacks:**
- `run(input, opts) :: {:ok, output} | {:error, term}`
- `validate_options(opts) :: :ok | {:error, term}` (optional)
- `nested?() :: boolean` (auto-generated)

**Helpers:**
- `report(opts, progress, payload) :: :ok`

---

## Recipe API

### `Recipe.new(steps, opts \\ [])`
Create a recipe.

**Args:**
- `steps`: list of step definitions
- `opts`: `[name: atom]`

**Returns:** `Recipe` struct

---

### `Recipe.validate_steps(steps, initial_keys)`
Validate recipe before execution.

**Returns:** `:ok | {:error, {reason, details}}`

---

### `Recipe.assign_options(recipe, selector, new_opts)`
Inject options into steps.

**Selector:**
- `:all` - match all steps
- `Module` - match by implementation
- `fn step -> bool` - custom predicate

**Returns:** modified `Recipe`

---

### `Recipe.walk(steps, func, mode \\ :step)`
Traverse recipe tree.

**Mode:**
- `:step` - modify step definitions
- `:inner_recipe` - modify nested recipes

**Returns:** modified steps

---

## Param API

### `Param.new(name, type, payload \\ nil, metadata \\ %{})`
Create parameter.

**Returns:** `Param` struct

---

### `Param.get_payload(param)`
Extract payload.

**Returns:** payload value

---

### `Param.set_payload(param, new_payload)`
Update payload.

**Returns:** modified `Param`

---

## Hook API

### `@behaviour Orchid.Runner.Hook`
Implement a hook.

**Callback:**
```elixir
def call(ctx, next) do
  # Pre-execution
  case next.(ctx) do
    {:ok, result} -> # Post-success
    {:error, reason} -> # Post-failure
  end
end
```

**Hook Result:**
- `{:ok, output}` - success
- `{:error, reason}` - failure
- `{:special, data}` - plugin-specific result

---

## Error Handling

### `Orchid.Error` struct
```elixir
%Orchid.Error{
  reason: term,           # The actual error
  context: Context | nil, # Execution state when failed
  step_id: term,          # Which step failed
  kind: :logic | :exception | :exit | :logic_or_exception
}
```

---

## Executor Behavior

### `@behaviour Orchid.Executor`

**Callback:**
```elixir
def execute(context, opts) :: {:ok, results} | {:error, Error}
```

**Helpers:**
- `Executor.execute_next_step(ctx)` - run one step
- `Scheduler.next_ready_steps(ctx)` - get runnable steps
- `Scheduler.merge_result(ctx, idx, output)` - record result

---

## Scheduler API

### `Scheduler.build(recipe, params, workflow_ctx)`
Initialize execution context.

**Returns:** `{:ok, Context} | {:error, reason}`

---

### `Scheduler.next_ready_steps(ctx)`
Get steps ready to run.

**Returns:** `[{Step, index}]`

---

### `Scheduler.merge_result(ctx, step_idx, outputs)`
Record step result.

**Returns:** updated `Context`

---

### `Scheduler.done?(ctx)`
Check if workflow complete.

**Returns:** boolean

---

## WorkflowCtx API

### `WorkflowCtx.new()`
Create empty context.

---

### `WorkflowCtx.merge_baggage(ctx, data)`
Add custom data.

---

### `WorkflowCtx.get_baggage(ctx, key, default)`
Retrieve custom data.

---

### `WorkflowCtx.get_config(ctx, key, default)`
Retrieve config value.

```

---

### `reference/PATTERNS.md`

```markdown
# Orchid Design Patterns

## 1. Data Transformation Pipeline

**Problem**: Multi-stage data processing with validation.

**Solution**: Linear recipe with each step validating input.

```elixir
steps = [
  {FetchData, :source, :raw},
  {ValidateFormat, :raw, :format_ok},
  {ParseData, :format_ok, :parsed},
  {ValidateSchema, :parsed, :valid},
  {Transform, :valid, :output}
]

recipe = Recipe.new(steps, name: :etl_pipeline)
```

**Advantages:**
- Clear data flow
- Easy to debug (each step is observable)
- Reusable components

---

## 2. Fan-Out / Fan-In

**Problem**: Parallel processing of independent tasks, then merge.

**Solution**: Steps with no dependencies, then join step.

```elixir
steps = [
  {FetchUserData, :user_id, :user},
  {FetchOrderHistory, :user_id, :orders},    # Independent
  {FetchRecommendations, :user_id, :recs},   # Independent
  {MergeProfile, [:user, :orders, :recs], :profile}  # Merge all
]
```

**Advantages:**
- Parallel execution saves time
- Async executor scales naturally
- Easy to add more parallel steps

---

## 3. Conditional Branch (via Sub-recipes)

**Problem**: Different processing paths based on data.

**Solution**: Use NestedStep with conditional logic inside.

```elixir
defmodule ConditionalNested do
  use Orchid.Step
  @orchid_step_nested true
  
  def run(input, opts) do
    inner_recipe = Keyword.fetch!(opts, :recipe)
    
    # Choose recipe dynamically
    recipe = case Param.get_payload(input) do
      {:type, :A} -> recipe_a()
      {:type, :B} -> recipe_b()
    end
    
    Orchid.run(Recipe.new(recipe), [input])
  end
end
```

---

## 4. Error Recovery with Fallback

**Problem**: Primary method fails, try backup.

**Solution**: Catch error and retry with different recipe.

```elixir
def process_with_fallback(data) do
  primary = Recipe.new([{PrimaryMethod, ...}])
  fallback = Recipe.new([{FallbackMethod, ...}])
  
  case Orchid.run(primary, [data]) do
    {:ok, result} -> {:ok, result}
    {:error, %Error{reason: :timeout}} ->
      Logger.warn("Primary timed out, using fallback")
      Orchid.run(fallback, [data])
    {:error, e} -> {:error, e}
  end
end
```

---

## 5. Authorization Gate

**Problem**: Only allow certain users to run sensitive steps.

**Solution**: Use auth hook to guard restricted steps.

```elixir
defmodule AuthGate do
  @behaviour Orchid.Runner.Hook
  
  def call(ctx, next) do
    user_role = Orchid.WorkflowCtx.get_baggage(ctx.workflow_ctx, :user_role)
    
    restricted = [DeleteDataStep, ModifyConfigStep]
    if ctx.step_implementation in restricted and user_role != :admin do
      {:error, :unauthorized}
    else
      next.(ctx)
    end
  end
end

# Use:
steps = [
  {ReadStep, ...},
  {DeleteDataStep, ..., [extra_hooks_stack: [AuthGate]]},
  ...
]
```

---

## 6. Long-Running Step with Progress

**Problem**: Step takes minutes; need to report progress.

**Solution**: Step calls `report/2` periodically.

```elixir
def run(input, opts) do
  total = Param.get_payload(input)
  
  result = Enum.reduce(1..total, [], fn i, acc ->
    # Every 100 items, report progress
    if rem(i, 100) == 0 do
      Step.report(opts, :progress, "#{i}/#{total}")
    end
    
    [process_item(i) | acc]
  end)
  
  {:ok, Param.new(:result, :list, Enum.reverse(result))}
end
```

---

## 7. Distributed Context (Request Tracing)

**Problem**: Need to track request through all steps for debugging.

**Solution**: Pass request ID in baggage, access in steps.

```elixir
Orchid.run(recipe, params,
  baggage: %{
    request_id: "req-#{UUID.uuid4()}",
    trace_id: "trace-#{UUID.uuid4()}",
    user_id: current_user.id
  }
)

# In step:
def run(input, opts) do
  ctx = Orchid.Runner.Hooks.Core.extract_workflow_ctx(opts)
  request_id = Orchid.WorkflowCtx.get_baggage(ctx, :request_id)
  
  Logger.info("Processing", request_id: request_id)
end
```

---

## 8. Composite Workflow (Modular Architecture)

**Problem**: Large workflow split across teams.

**Solution**: Each team owns sub-recipe, compose at top level.

```elixir
# Team A owns:
def data_cleaning_pipeline, do: Recipe.new([...], name: :cleaning)

# Team B owns:
def ml_training_pipeline, do: Recipe.new([...], name: :training)

# Platform team composes:
def full_workflow do
  Recipe.new([
    {FetchData, :source, :raw},
    {Orchid.Step.NestedStep, :raw, :clean,
      [recipe: data_cleaning_pipeline()]},
    {Orchid.Step.NestedStep, :clean, :trained,
      [recipe: ml_training_pipeline()]},
    {SaveResults, :trained, :done}
  ])
end
```

**Advantages:**
- Teams work independently
- Easy to test sub-recipes
- Clear ownership

---

## 9. Caching Layer

**Problem**: Step is expensive; many workflows repeat it.

**Solution**: Use caching hook.

```elixir
defmodule CachedStep do
  @behaviour Orchid.Runner.Hook
  
  @cache_ttl 3600  # 1 hour
  
  def call(ctx, next) do
    cache_key = make_key(ctx)
    
    case fetch_cache(cache_key) do
      {:hit, value} -> {:ok, value}
      :miss ->
        case next.(ctx) do
          {:ok, result} ->
            store_cache(cache_key, result, @cache_ttl)
            {:ok, result}
          error -> error
        end
    end
  end
  
  defp make_key(ctx) do
    :erlang.phash2({ctx.step_implementation, ctx.inputs})
  end
end

# Use:
{YourExpensiveStep, :input, :output,
  [extra_hooks_stack: [CachedStep]]}
```

---

## 10. Backpressure-Aware Execution

**Problem**: Too many parallel tasks, memory exploding.

**Solution**: Custom executor with concurrency limit.

See `skill_templates/custom_executor.ex` for `BackpressureExecutor`.

```elixir
Orchid.run(recipe, params,
  executor_and_opts: {MyApp.Executors.BackpressureExecutor,
    [concurrency: 4, max_queue_depth: 10]})
```
