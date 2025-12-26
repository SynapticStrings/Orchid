defmodule Orchid do
  @moduledoc """
  The core entry point for the Orchid workflow engine.

  This module provides the primary interface (`run/3`) to execute defined Recipes.
  It is designed to be a flexible and extensible framework for task orchestration.
  """

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

  ### Examples

      # Normal execution returning {:ok, results}
      Orchid.run(my_recipe, initial_params)

      # Execution returning the full Response struct
      Orchid.run(my_recipe, initial_params, return_response: true)
  """
  @spec run(Orchid.Recipe.t(), Orchid.Scheduler.initial_params(), keyword()) ::
          Orchid.Operon.Response.payload() | Orchid.Operon.Response.t()
  def run(recipe, input_params, opts \\ []) do
    # Fetch keys and inject into Orchid.WorkflowCtx struct
    run_with_ctx(
      recipe,
      input_params,
      Orchid.WorkflowCtx.new() |> Orchid.WorkflowCtx.merge_config(opts)
    )
  end

  @spec run_with_ctx(
          Orchid.Recipe.t(),
          Orchid.Scheduler.initial_params(),
          Orchid.WorkflowCtx.t()
        ) ::
          Orchid.Operon.Response.payload() | Orchid.Operon.Response.t()
  def run_with_ctx(recipe, input_params, workflow_ctx) do
    response? = Orchid.WorkflowCtx.get_config(workflow_ctx, :return_response, false)
    operons_stack = Orchid.WorkflowCtx.get_config(workflow_ctx, :operons_stack, [])

    executor_and_opts =
      Orchid.WorkflowCtx.get_config(workflow_ctx, :executor_and_opts, {Orchid.Executor.Async, []})

    response =
      Orchid.Pipeline.run(
        operons_stack ++ [Orchid.Operon.Execute],
        %Orchid.Operon.Request{
          recipe: recipe,
          inital_params: input_params,
          executor_and_opts: executor_and_opts,
          workflow_ctx: workflow_ctx
        }
      )

    if response?, do: response, else: response.payload
  end
end
