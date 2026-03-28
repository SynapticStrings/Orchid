defmodule Orchid do
  @moduledoc """
  The core entry point for the Orchid workflow engine.

  This module provides the primary interface (`run/3`) to execute defined Recipes.
  It is designed to be a flexible and extensible framework for task orchestration.
  """
  alias Orchid.{Recipe, Step, Pipeline, Scheduler, WorkflowCtx}
  alias Orchid.Operon.{Request, Response, Execute}

  @allow_config_keys [
    :return_response,
    :operons_stack,
    :global_hooks_stack,
    :executor_and_opts,
    :core_hook
  ]

  @doc """
  Executes a workflow Recipe.

  It initializes the pipeline, injects any configured middleware (Operons), and
  starts the execution process.

  ### Options

  * `:return_response` - (boolean) If `true`, returns the full `Orchid.Operon.Response` struct
    (which includes assigns and metadata) instead of just the result payload. Defaults to `false`.
  * `:operons_stack` - (list) A list of additional middleware modules (Recipe-level hooks)
    to run before the execution phase. They are executed in the order provided.
  * `:global_hooks_stack` - (list)
  * `:executor_and_opts` - (tuple) Executor module and its options.
  * `:core_hook` - (module) A Module for execute step.
  * `:baggage` - (enumerable) Custom options used by user/custome operons/hooks/etc.

  ### Examples

      # Normal execution returning {:ok, results}
      Orchid.run(my_recipe, initial_params)

      # Execution returning the full Response struct
      Orchid.run(my_recipe, initial_params, return_response: true)
  """
  @spec run(Recipe.t() | [Step.t()], Scheduler.initial_params(), keyword()) ::
          Response.payload() | Response.t()
  def run(recipe_or_steps, input_params, opts \\ []) do
    initial_config = Keyword.filter(opts, fn {k, _v} -> k in @allow_config_keys end)

    ctx =
      WorkflowCtx.new()
      |> WorkflowCtx.merge_config(initial_config)
      |> WorkflowCtx.merge_baggage(Keyword.get(opts, :baggage, []))

    run_with_ctx(recipe_or_steps, input_params, ctx)
  end

  @doc "Run with explicit WorkflowContext struct."
  @spec run_with_ctx(Recipe.t() | [Step.t()], Scheduler.initial_params(), WorkflowCtx.t()) ::
          Response.payload() | Response.t()
  def run_with_ctx(steps, input_params, workflow_ctx) when is_list(steps) do
    run_with_ctx(Recipe.new(steps), input_params, workflow_ctx)
  end
  def run_with_ctx(recipe, input_params, workflow_ctx) do
    response? = WorkflowCtx.get_config(workflow_ctx, :return_response, false)
    operons_stack = WorkflowCtx.get_config(workflow_ctx, :operons_stack, [])

    initial_request = %Request{
      recipe: recipe,
      initial_params: input_params,
      workflow_ctx: workflow_ctx
    }

    response = Pipeline.run(operons_stack ++ [Execute], initial_request)

    if response?, do: response, else: response.payload
  end
end
