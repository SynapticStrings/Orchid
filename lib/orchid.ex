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
    response? = Keyword.get(opts, :return_response, false)
    operons_stack = Keyword.get(opts, :operons_stack, [])
    executor_and_opts = Keyword.get(opts, :executor_and_opts, {Orchid.Executor.Async, []})
    # TODO: prograte `operons_stack` and `executor_and_opts`
    # to inner recipes(exclude explicit configurations)

    response =
      Orchid.Pipeline.run(
        operons_stack ++ [Orchid.Operon.Execute],
        %Orchid.Operon.Request{
          recipe: recipe,
          inital_params: input_params,
          executor_and_opts: executor_and_opts
        }
      )

    if response? do
      response
    else
      response.payload
    end
  end
end
