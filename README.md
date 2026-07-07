# Orchid

[![Hex.pm](https://img.shields.io/hexpm/v/orchid.svg)](https://hex.pm/packages/orchid) ![GitHub License](https://img.shields.io/github/license/SynapticStrings/Orchid?style=flat) [![codecov](https://codecov.io/gh/SynapticStrings/Orchid/graph/badge.svg?token=7RCC5ERU71)](https://codecov.io/gh/SynapticStrings/Orchid) ![GitHub commit activity](https://img.shields.io/github/commit-activity/w/SynapticStrings/Orchid?style=flat)

![img](assets/HeroImage.jpg)

Orchid is an Elixir-based workflow orchestration engine inspired by a [personal project](https://ges233.github.io/2025/03/Qy-Editor-demo/)(written in Chinese).

It is primarily designed for scenarios requiring complex processing of data(time series limited originally) with low real-time demands, providing a relevant protocol or interface for subsequent development.

## Features

* **Declarative Recipes**: Define your workflow steps and dependencies clearly.
* **Flexible Execution**: Switch execution strategies(or implement and use yours) without changing business logic.
* **Composable & Nested**: Treat entire recipes as atomic steps (`NestedStep`). Supports deep configuration inheritance and parameter mapping.
* **Dependency Resolution**: Automatic topological sorting of steps based on input/output keys.
* **Onion-like Hooks**: Inject custom logic (logging, telemetry, etc.) at both the Step and Recipe levels.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:orchid, "~> 0.6"}
  ]
end
```

## Quick Start

Well, let's make a cup of coffee to see how Orchid works.

We will define a process where beans are ground into powder, and then brewed with water. Notice how we can control the brewing style using opts.

### Define Steps

Create modules that use `Orchid.Step`, or simply function with 2 arities.

```elixir
defmodule Barista.Grind do
  use Orchid.Step
  alias Orchid.Param

  # Simple 1-to-1 transformation
  def run(beans, opts) do
    amount = Param.get_payload(beans)
    IO.puts("⚙️  Grinding #{amount}g beans...")
    # You need use `{:ok, res}` or `{:error, term}` explicitly.
    {:ok, Param.new(:powder, :solid, amount * Keyword.get(opts, :ratio, 1))}
  end
end

defmodule Barista.Brew do
  use Orchid.Step
  alias Orchid.Param

  # Multi-input step with options
  def run([powder, water], opts) do
    # Get configuration from opts, default is :espresso
    style = Keyword.get(opts, :style, :espresso)
    
    p_amount = Param.get_payload(powder)
    w_amount = Param.get_payload(water)
    
    IO.puts("💧 Brewing #{style} coffee with #{p_amount}g powder and #{w_amount}ml water...")
    {:ok, Param.new(:coffee, :liquid, "Cup of #{style}")}
  end
end
```

### Build Recipe

Define the workflow. Key features demonstrated here:

- **Out of Order**: We define Brew before Grind, but Orchid will figure it out.
- **Options**: We pass style: :latte to the brewing step.

```elixir
alias Orchid.{Recipe, Param}

# Initial Ingredients
inputs = [
  Param.new(:beans, :raw, 20),    # 20g beans
  Param.new(:water, :raw, 200)    # 200ml water
]

steps = [
  # Step 2: Brew (Depends on :powder and :water)
  # We want a Latte, so we pass options here.
  {Barista.Brew, [:powder, :water], :coffee, [style: :latte]},

  # Step 1: Grind (Depends on :beans, Provides :powder)
  {Barista.Grind, :beans, :powder}
]

recipe = Recipe.new(steps, name: :morning_routine)
```

### Run

Execute the recipe. Orchid automatically resolves dependencies: `Grind` runs first, then `Brew`.

```elixir
{:ok, results} = Orchid.run(recipe, inputs)
# Output:
# ⚙️  Grinding 20g beans...
# 💧 Brewing latte coffee with 20g powder and 200ml water...

IO.inspect(Param.get_payload(results[:coffee]))
# => "Cup of latte"
```

## Advanced Usage

### Executors

Orchid includes two built-in executors:

- `Orchid.Executor.Serial`: Runs steps one by one. Good for debugging.
- `Orchid.Executor.Async`: Runs independent steps in parallel based on the dependency graph.

You can switch executors via the `:executor_and_opts` option passed to `Orchid.run/3`.

```elixir
# Run sequentially
Orchid.run(recipe, inputs, executor_and_opts: {Orchid.Executor.Serial, []})

# Run concurrently with a limit of 4 tasks
Orchid.run(recipe, inputs, executor_and_opts: {Orchid.Executor.Async, [concurrency: 4]})
```

As business complexity increases dramatically (e.g., external resource monitoring, more fault-tolerant business environments, execute as stream), custom Executors implementing the `Orchid.Executor` behaviour are encouraged.

### Nested Steps (NestedRecipe)

You can treat an entire `Recipe` as a single Step within a parent workflow. This is achieved via `Orchid.Step.NestedStep`.

#### Implicit Mapping (Recommended)

If the input/output keys in the parent step definition match the keys expected/produced by the inner recipe, you don't need to write any mapping configuration. Orchid will handle the data passing automatically.

```elixir
alias Orchid.Step.NestedStep, as: Nested

# 1. Define the inner recipe
# It expects :child_raw and produces :child_tuned
child_recipe =
  Recipe.new([
    {Denoise, :child_raw, :child_clean},
    {PitchFix, :child_clean, :child_tuned}
  ])

# 2. Use it in the parent recipe
# Notice the keys match the inner recipe's interface
main_recipe =
  Recipe.new([
    {Nested, :child_raw, :child_tuned, [recipe: child_recipe]},
    {Mix, [:child_tuned, :bgm], :final_mix}
  ])

# Inputs match the keys defined in the parent step
initial_params = [
  Param.new(:child_raw, :audio, ["Vocal1"]),
  Param.new(:bgm, :audio, ["Beat1"])
]

{:ok, results} = Orchid.run(main_recipe, initial_params)
```

#### Explicit Mapping

It also supports parameter mapping to adapt names between the parent and child contexts.

If the parent context uses different names for the parameters, you can use `:input_map` and `:output_map` to bridge the gap.

```elixir
# Define an inner recipe
inner_steps = [
  {Barista.Grind, :inner_beans, :inner_powder}
]
inner_recipe = Orchid.Recipe.new(inner_steps)

# Use it in a parent recipe
parent_steps = [
  # Map :parent_beans -> :inner_beans for input
  # Map :inner_powder -> :ground_beans for output
  {Orchid.Step.NestedStep, :parent_beans, :ground_beans,
   [
     recipe: inner_recipe,
     input_map: %{parent_beans: :inner_beans},
     output_map: %{inner_powder: :ground_beans}
   ]},
   
  {Barista.Brew, [:ground_beans, :water], :coffee}
]

Orchid.run(Orchid.Recipe.new(parent_steps), inputs)
```

### Layered Hooks

Orchid employs an onion-like execution model (similar to Rack or Plug middleware), where hooks wrap around the core logic.

*Note: This refers to the runtime call stack, distinct from the 'Onion Architecture' design pattern which concerns static code dependencies and domain boundaries.*

#### Step Level (Hook)

Within `Orchid.Runner`, which is responsible for executing steps, data flows like an onion from the outer layers through the inner layers and back to the outer layers.

The general flow for each hook is as follows:

```elixir
defmodule MyHook do
  @behaviour Orchid.Runner.Hook

  @impl true
  def call(ctx, next) do
    # Prelude
    ...

    # Execute inner part
    case next.(ctx) do
      # When success and get result
      {:ok, result} ->
        ...

      # Reserved for plugin
      {:special, _any} ->
        ...

      # When failed
      {:error, term} ->
        ...
    end
  end
end
```

To run additional Hooks, configure them in the step's options:

```elixir
{MyStep, :input, :output, [extra_hooks_stack: [MyHook, AnotherHook]]}
```

Or globally for the recipe:

```elixir
Orchid.run(recipe, inputs, global_hooks_stack: [GlobalHook])
```

Currently, the default Runner hooks are:
- `Orchid.Runner.Hooks.Telemetry` for telemetry
- `Orchid.Runner.Hooks.Core` for executing the step logic

### Vertical-propagated Context (Baggage)

Allows propagating global data deeply into nested steps. This is useful for tracing or passing configuration without explicitly threading it through every step definition.

```elixir
# Pass baggage at runtime
Orchid.run(recipe, inputs, baggage: %{transaction_id: 123, trace_id: "abc"})

# Access baggage inside a step
def run(input, opts) do
  # Extract the WorkflowCtx injected by the Core hook
  ctx = Orchid.Runner.Hooks.Core.extract_workflow_ctx(opts)
  transaction_id = Orchid.WorkflowCtx.get_baggage(ctx, :transaction_id)
  
  # ... logic ...
end
```

### Pipeline Middleware (Operons)

Similar to hooks, data is also processed in an onion-like flow, but at the Recipe level.

It has a somewhat peculiar name called "Operon" (may be changed later).

```elixir
defmodule QyPersist do
  @behavior Orchid.Operon

  @impl true
  def call(%Request{} = req_before, next_fn) do
    # Modify request or recipe before execution
    new_req = %{req | recipe: modify_recipe(req.recipe)}

    next_fn.(req)
  end
end
```

The execution is handled by `Orchid.Pipeline` which calls a series of middleware conforming to the `Orchid.Operon` protocol.

Configure Operons via the `:operons_stack` option:

```elixir
Orchid.run(recipe, inputs, operons_stack: [QyPersist])
```

The default terminal Operon is `Orchid.Operon.Execute`, which wraps the Executor.

## Libs

* [`OrchidSymbiont`](https://hex.pm/packages/orchid_symbiont)
  * Let Orchid can execute steps where required HEAVY service(Ortex service(via NxServing), ErlPort, NIF, HTTP request, etc.).
