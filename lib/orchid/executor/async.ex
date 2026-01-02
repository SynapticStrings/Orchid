defmodule Orchid.Executor.Async do
  # record opts into moduledoc
  @behaviour Orchid.Executor
  alias Orchid.Scheduler

  defstruct [
    :tasks,
    :max_concurrency,
    :recipe,
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
            # This would theoretically be intercepted by `Graph.validate`,
            # but serves as a runtime safeguard.
            {:error,
             %Orchid.Error{
               reason: :stuck_at_runtime,
               context: ctx,
               step_id: nil,
               kind: :exception
             }}
          end
      end
    end
  end

  defp launch_steps(ctx, state, steps) do
    step_indices = Enum.map(steps, fn {_, idx} -> idx end)
    updated_ctx = Scheduler.mark_running_steps(ctx, step_indices, :running)

    new_tasks =
      Enum.reduce(steps, state.tasks, fn {step, idx}, acc_tasks ->
        task =
          Task.async(fn ->
            Orchid.Runner.run(step, ctx.params, state.recipe.opts, ctx.workflow_ctx)
          end)

        Map.put(acc_tasks, task.ref, {step, idx})
      end)

    {updated_ctx, %{state | tasks: new_tasks}}
  end

  defp wait_for_result(ctx, state) do
    receive do
      {ref, result} when is_reference(ref) ->
        {{step, step_idx}, remaining_tasks} = Map.pop(state.tasks, ref)
        # MUST do this to avoid receiving :DOWN message later
        Process.demonitor(ref, [:flush])

        case result do
          {:ok, outputs} ->
            new_ctx = Scheduler.merge_result(ctx, step_idx, outputs)
            loop(new_ctx, %{state | tasks: remaining_tasks})

          {:special, _plugin_context} ->
            cleanup_tasks(remaining_tasks)

            err = %Orchid.Error{
              reason: :core_executor_not_support_special,
              context: ctx,
              step_id: Orchid.Step.ID.finger_print(step),
              kind: :exception
            }

            {:error, err}

          {:error, reason} ->
            cleanup_tasks(remaining_tasks)

            err = %Orchid.Error{
              reason: reason,
              context: ctx,
              step_id: Orchid.Step.ID.finger_print(step),
              kind: :logic_or_exception
            }

            {:error, err}
        end

      {:DOWN, ref, :process, _pid, reason} ->
        # caught task crash
        # it requires consider whether the race condition would impact the executor
        # (although in current project it would just crash together and return {:error, blabla})
        {{step, _step_idx}, remaining_tasks} = Map.pop(state.tasks, ref)
        cleanup_tasks(remaining_tasks)

        err = %Orchid.Error{
          reason: reason,
          context: ctx,
          step_id: Orchid.Step.ID.finger_print(step),
          kind: :exit
        }

        {:error, err}
    end
  end

  # Sends a shutdown signal to ALL concurrent tasks
  defp cleanup_tasks(tasks) do
    tasks
    |> Enum.each(fn {_ref, {task, _idx}} ->
      Task.shutdown(task, :brutal_kill)

      :ok
    end)
  end
end
