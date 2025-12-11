defmodule Orchid.Executor.Async do
  @behaviour Orchid.Executor
  alias Orchid.Scheduler

  defstruct [
    # Map: %{ref => step_idx}
    :tasks,
    :max_concurrency,
    :recipe,
    # 记录是否需要清理
    :trap_exit?
  ]

  @impl true
  def execute(ctx, opts) do
    state = %__MODULE__{
      tasks: %{},
      max_concurrency: Keyword.get(opts, :concurrency, System.schedulers_online()),
      recipe: ctx.recipe
    }

    try do
      loop(ctx, state)
    catch
      :exit, reason -> {:error, {:executor_crashed, reason}}
    end
  end

  defp loop(ctx, state) do
    current_load = map_size(state.tasks)

    if current_load >= state.max_concurrency do
      wait_for_result(ctx, state)
    else
      ready_steps = Scheduler.next_ready_steps(ctx)
      slots_available = state.max_concurrency - current_load
      steps_to_launch = Enum.take(ready_steps, slots_available)

      cond do
        length(steps_to_launch) > 0 ->
          {new_ctx, new_state} = launch_steps(ctx, state, steps_to_launch)
          loop(new_ctx, new_state)

        current_load > 0 ->
          wait_for_result(ctx, state)

        true ->
          if Scheduler.done?(ctx) do
            {:ok, Scheduler.get_results(ctx)}
          else
            # 这里理论上在 Graph.validate 就会被拦截，但作为运行时保险
            {:error, :stuck_at_runtime}
          end
      end
    end
  end

  defp launch_steps(ctx, state, steps) do
    step_indices = Enum.map(steps, fn {_, idx} -> idx end)
    updated_ctx = Scheduler.mark_running(ctx, step_indices)

    new_tasks =
      Enum.reduce(steps, state.tasks, fn {step, idx}, acc_tasks ->
        # 使用 Task.async 启动，它会链接当前进程
        # 但需要确定 Executor 进程可能因为运行 step 的进程崩溃而宕机的可能性
        task =
          Task.async(fn ->
            Orchid.Runner.run(step, ctx.params, state.recipe.opts)
          end)

        Map.put(acc_tasks, task.ref, {step, idx})
      end)

    {updated_ctx, %{state | tasks: new_tasks}}
  end

  defp wait_for_result(ctx, state) do
    receive do
      {ref, result} when is_reference(ref) ->
        {{_step, step_idx}, remaining_tasks} = Map.pop(state.tasks, ref)
        # 必须显式 demonitor 并且 flush，防止 :DOWN 消息污染邮箱
        Process.demonitor(ref, [:flush])

        case result do
          {:ok, outputs} ->
            new_ctx = Scheduler.merge_result(ctx, step_idx, outputs)
            loop(new_ctx, %{state | tasks: remaining_tasks})

          {:error, reason} ->
            # Fail-Fast: 立即终止其他所有正在运行的任务
            cleanup_tasks(remaining_tasks)
            {:error, {:step_failed, step_idx, reason}}
        end

      {:DOWN, ref, :process, _pid, reason} ->
        # 捕获 Task crash
        # 需考虑极端情况下的 Race condition 可能对 Executor 带来影响
        # （虽然按照目前的项目会一并崩掉返回 {:error, blabla} 罢了）
        {{_step, step_idx}, remaining_tasks} = Map.pop(state.tasks, ref)
        cleanup_tasks(remaining_tasks)
        {:error, {:step_crashed, step_idx, reason}}
    end
  end

  # 暴力清理：向所有并发任务发送 shutdown
  defp cleanup_tasks(tasks) do
    tasks
    |> Enum.each(fn {_ref, {task, _idx}} ->
      Task.shutdown(task, :brutal_kill) |> IO.inspect()

      :ok
    end)
  end
end
