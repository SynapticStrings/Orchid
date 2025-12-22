defmodule Orchid.Executor do
  @moduledoc """
  Executor behavoir.

  An executor receive a `Orchid.Scheduler.Context` struct and do execution.

  There're some functions recommend to use during execution.

  * `Orchid.Scheduler.next_ready_steps/1`
  * `Orchid.Scheduler.merge_result/3`
  * `Orchid.Scheduler.mark_running_steps/3`
  * `Orchid.Scheduler.done?/1`
  * `Orchid.Runner.run/3`
  """

  @type executor :: module()
  @type executor_opts :: keyword()

  @type response :: {:ok, Orchid.Scheduler.Context.param_map()} | {:error, term()}

  @callback execute(Orchid.Scheduler.Context.t(), executor_opts()) ::
              response()

  @doc """
  Executes the next ready step in the given context.

  Debugging helpers.
  """
  def execute_next_step(ctx) do
    case {Orchid.Scheduler.next_ready_steps(ctx), Orchid.Scheduler.done?(ctx)} do
      {[], true} ->
        {:done, ctx}

      {[], false} ->
        {:stuck, ctx}

      {[{step, idx} | _], _} ->
        case Orchid.Runner.run(step, ctx.params, ctx.recipe.opts) do
          {:ok, result} -> Orchid.Scheduler.merge_result(ctx, idx, result)
          error -> error
        end
    end
  end
end
