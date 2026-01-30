# Template: Custom Executor with Backpressure
defmodule MyApp.Executors.BackpressureExecutor do
  @behaviour Orchid.Executor
  alias Orchid.Scheduler

  @impl true
  def execute(ctx, opts) do
    max_queue_depth = Keyword.get(opts, :max_queue_depth, 10)
    max_concurrency = Keyword.get(opts, :concurrency, 4)

    loop(ctx, max_concurrency, max_queue_depth, MapSet.new())
  end

  defp loop(ctx, max_concurrency, max_queue_depth, active_tasks) do
    cond do
      # All done
      Scheduler.done?(ctx) and MapSet.size(active_tasks) == 0 ->
        {:ok, Scheduler.get_results(ctx)}

      # At capacity
      MapSet.size(active_tasks) >= max_concurrency ->
        wait_for_one(ctx, active_tasks, max_concurrency, max_queue_depth)

      # Can launch more
      true ->
        ready = Scheduler.next_ready_steps(ctx)

        if Enum.empty?(ready) do
          if MapSet.size(active_tasks) > 0 do
            wait_for_one(ctx, active_tasks, max_concurrency, max_queue_depth)
          else
            {:error, %Orchid.Error{reason: :stuck, context: ctx, kind: :exception}}
          end
        else
          {step, idx} = List.first(ready)

          # Launch task
          task = Task.async(fn ->
            Orchid.Runner.run(step, ctx.params, ctx.recipe.opts, ctx.workflow_ctx)
          end)

          updated_ctx = Scheduler.mark_running_steps(ctx, idx, :running)
          new_active = MapSet.put(active_tasks, task.ref)

          loop(updated_ctx, max_concurrency, max_queue_depth, new_active)
        end
    end
  end

  defp wait_for_one(ctx, active_tasks, max_concurrency, max_queue_depth) do
    receive do
      {ref, result} when is_reference(ref) ->
        # Find which step this was
        step_idx = find_step_idx(ctx, ref)

        # Cleanup
        Process.demonitor(ref, [:flush])
        new_active = MapSet.delete(active_tasks, ref)

        case result do
          {:ok, outputs} ->
            updated_ctx = Scheduler.merge_result(ctx, step_idx, outputs)
            loop(updated_ctx, max_concurrency, max_queue_depth, new_active)

          {:error, reason} ->
            {:error, %Orchid.Error{reason: reason, context: ctx, kind: :exception}}
        end

      {:DOWN, ref, :process, _pid, reason} ->
        {:error, %Orchid.Error{reason: reason, context: ctx, kind: :exit}}
    end
  end

  defp find_step_idx(ctx, ref) do
    # Implementation: map ref to step_idx
    # (In real code, maintain a task → step_idx map)
    0
  end
end
