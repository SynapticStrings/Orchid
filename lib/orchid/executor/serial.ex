defmodule Orchid.Executor.Serial do
  @moduledoc """
  Serial Executor, implementing the behaviour of `Orchid.Executor`.

  It executes the steps within a Recipe sequentially, performing only
  one step at a time and waiting for its completion before proceeding
  to the next step.
  """
  @behaviour Orchid.Executor
  alias Orchid.Scheduler

  @impl true
  def execute(ctx, _executor_opts \\ []) do
    loop(ctx, ctx.recipe.opts)
  end

  defp loop(ctx, opts) do
    case Scheduler.next_ready_steps(ctx) do
      [] ->
        if Scheduler.done?(ctx) do
          {:ok, Scheduler.get_results(ctx)}
        else
          {:error, :stuck}
        end

      # 串行只取第一个
      [{step, idx} | _] ->
        case Orchid.Runner.run(step, ctx.params, opts) do
          {:ok, renamed_output} ->
            loop(Scheduler.merge_result(ctx, idx, renamed_output), opts)

          error ->
            error
        end
    end
  end
end
