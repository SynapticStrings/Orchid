# Orchid

Orchid is an Elixir-based workflow orchestration engine inspired by a [personal project](https://ges233.github.io/2023/06/Qy-project/)(written in Chinese).

It is primarily designed for scenarios requiring complex processing of time series (or sequences related to time series) with low real-time demands, providing a relevant protocol or interface for subsequent development.

## Features

* **Declarative Recipes**: Define your workflow steps and dependencies clearly.
* **Flexible Execution**: Switch execution strategies(or implement and use yours) without changing business logic.
* **Dependency Resolution**: Automatic topological sorting of steps based on input/output keys.
* **Onion-like Hooks**: Inject custom logic (logging, telemetry, etc.) at both the Step and Recipe levels.

## Installation

Add to your `mix.exs`:

```elixir
def deps do
  [
    {:orchid, "~> 0.3.0"}
  ]
end
```

## Quick Start

Here is a simple example of how to define steps, create a recipe, and run the workflow.

### Definate Steps

Create modules that use `Orchid.Step`, or simply function with 2 arities.

```elixir
...
```

### Build Recipe

Define the data flow. Note that we don't strictly specify the order; Orchid resolves it based on inputs/outputs.

```elixir
steps = [
  ...
]
recipe = Orchid.Recipe.new(steps, name: :demo_recipe)
```

### Run

```elixir
{:ok, results} = Orchid.run(recipe, [])
```

## Core Components

### Defination

- `Orchid.Param`: The standard unit of data exchange. Every step receives and returns Param structs (or lists/tuples of them). It carries the payload and metadata.
- `Orchid.Step`: An atomic unit of work. It focuses solely on processing logic, unaware of the larger workflow context.
- `Orchid.Recipe`: The blueprint that describes what needs to be done and the data dependencies between steps.

### Orchestration

Mainly handled by the `Orchid.Scheduler` module.

### Execution

Recipe-level execution is the responsibility of the `Orchid.Executor` behavior.

In step-level, function `Orchid.Runner.run/3` will handle it.

### Architecture

#### Overview

*Separation of Definition, Orchestration, and Execution layers.*

![Overview](assets/Orchid_overview.svg)

#### Lifecycle

*How a request flows through the pipeline and executor(s).*

![Flowchart](assets/Orchid_flow.svg)

### Advanced Usage

### Executors

Currently, orchid includes two executors:

- `Orchid.Executor.Serial`: Runs steps one by one. Good for debugging.
- `Orchid.Executor.Async`: Runs independent steps in parallel based on the dependency graph.

Due to the atomic nature of Step operations, no further behavior-adapter design has been implemented. However, considering business complexity, a hook mechanism has been introduced.

### Layered Hooks

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
      # When success
      {:ok, result} ->
        ...

      # When failed
      {:error, term} ->
        ...
    end
  end
end
```

Therefore, the order and definition of Hooks need careful consideration.

To run additional Hooks, they must be configured in the step's `opts[:extra_hooks_stack]`.

Currently, Runner has two hooks:

- `Orchid.Runner.Hooks.Telemetry` for telemetry
- `Orchid.Runner.Hooks.Core` for executing the step

#### Pipeline Middleware (Operons)

Similar to hooks, data is also processed in an onion-like flow.

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

The execution is handled by `Orchid.Pipeline`  which calls a series of middleware conforming to the `Orchid.Operon` protocol.

However, the difference is that we define two structs: `Orchid.Operon.Request` and `Orchid.Operon.Response`.

The transformation module is `Orchid.Operon.Execute`, which wraps the Executor.

No additional middleware has been introduced yet, but it will be added later.

## NextStep

Let me take a rest, increase test coverage, consolidate API and **To Be Determined**.
