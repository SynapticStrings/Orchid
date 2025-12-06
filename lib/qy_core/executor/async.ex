defmodule QyCore.Executor.Async do
  @behaviour QyCore.Executor
  alias QyCore.Scheduler

  defstruct [
    :tasks,
    :max_concurrency,
    :recipe
  ]

  @impl true
  def execute(recipe, initial_params, opts \\ []) do
    case Scheduler.build(recipe, initial_params) do
      {:ok, ctx} ->
        state = %__MODULE__{
          tasks: %{},
          max_concurrency: Keyword.get(opts, :concurrency, System.schedulers_online()),
          recipe: recipe
        }
        loop(ctx, state)

      error -> error
    end
  end

  defp loop(ctx, state) do
    # A. 检查任务槽位：如果满载，就只等结果，不派发新任务
    current_load = map_size(state.tasks)

    if current_load >= state.max_concurrency do
      wait_for_result(ctx, state)
    else
      # B. 尝试派发新任务
      # 注意：next_ready_steps 现在会自动排除 running_steps
      ready_steps = Scheduler.next_ready_steps(ctx)

      # 能够启动的任务数
      slots_available = state.max_concurrency - current_load
      steps_to_launch = Enum.take(ready_steps, slots_available)

      cond do
        # 情况 1: 有任务可跑 -> 发射！
        length(steps_to_launch) > 0 ->
          {new_ctx, new_state} = launch_steps(ctx, state, steps_to_launch)
          loop(new_ctx, new_state)

        # 情况 2: 没任务可跑，但还有任务在运行 -> 等结果
        current_load > 0 ->
          wait_for_result(ctx, state)

        # 情况 3: 没任务可跑，也没任务在运行 -> 结束
        true ->
          if Scheduler.done?(ctx) do
            {:ok, Scheduler.get_results(ctx)}
          else
            {:error, :stuck} # 死锁或依赖无法满足
          end
      end
    end
  end

  defp launch_steps(ctx, state, steps) do
    # 1. 标记 Scheduler 状态
    step_indices = Enum.map(steps, fn {_, idx} -> idx end)
    updated_ctx = Scheduler.mark_running(ctx, step_indices)

    # 2. 启动异步任务
    new_tasks =
      Enum.reduce(steps, state.tasks, fn {step, idx}, acc_tasks ->
        # 这里调用上一轮设计的 StepRunner (Pipeline)
        task = Task.async(fn ->
          QyCore.Runner.run(step, ctx.params, state.recipe.opts)
        end)
        Map.put(acc_tasks, task.ref, idx)
      end)

    {updated_ctx, %{state | tasks: new_tasks}}
  end

  defp wait_for_result(ctx, state) do
    receive do
      # 捕获 Task 结果
      {ref, result} when is_reference(ref) ->
        # 1. 找到是哪个 step
        {step_idx, remaining_tasks} = Map.pop(state.tasks, ref)
        Process.demonitor(ref, [:flush])

        # 2. 处理结果
        case result do
          {:ok, outputs} ->
            # 合并结果 (Scheduler 会自动移除 running 状态)
            new_ctx = Scheduler.merge_result(ctx, step_idx, outputs)
            loop(new_ctx, %{state | tasks: remaining_tasks})

          {:error, reason} ->
            # 简单起见，有一个失败就全部崩溃。
            # 进阶：可以在这里做 Retry 逻辑，或者 Cancel 其他 Tasks
            {:error, {:step_failed, step_idx, reason}}
        end

      # 处理 Crash
      {:DOWN, ref, :process, _pid, reason} ->
        {step_idx, _} = Map.pop(state.tasks, ref)
        {:error, {:step_crashed, step_idx, reason}}
    end
  end
end
