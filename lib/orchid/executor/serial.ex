defmodule Orchid.Executor.Serial do
  @moduledoc """
  串行执行器，实现 `Orchid.Executor` 行为。
  它按顺序执行 Recipe 中的步骤，每次只执行一个步骤，等待其完成后再执行下一个步骤。
  默认的执行器即为串行执行器。
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
