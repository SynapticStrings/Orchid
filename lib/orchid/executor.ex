defmodule Orchid.Executor do
  @moduledoc """
  Executor behavoir.

  An executor receive a `Orchid.Scheduler.Context` struct and do execution.

  There're some functions recommend to use during execution.

  * `Orchid.Scheduler.next_ready_steps/1`
  * `Orchid.Scheduler.merge_result/3`
  * `Orchid.Scheduler.mark_running_steps/3`
  * `Orchid.Scheduler.done?/1`
  * `Orchid.Runner.run/4`
  """

  @type executor :: module()
  @type executor_opts :: keyword()

  @type response :: {:ok, Orchid.Scheduler.Context.param_map()} | {:error, Orchid.Error.t()}

  @callback execute(Orchid.Scheduler.Context.t(), executor_opts()) ::
              response()

  @doc """
  Executes the next ready step in the given context.

  Debugging helper function for executors.
  """
  @spec execute_next_step(Orchid.Scheduler.Context.t()) ::
          {:done, Orchid.Scheduler.Context.t()}
          | {:stuck, Orchid.Scheduler.Context.t()}
          | {:cont, Orchid.Scheduler.Context.t()}
          | {:error, Orchid.Error.t()}
  def execute_next_step(%Orchid.Scheduler.Context{} = ctx) do
    case {Orchid.Scheduler.next_ready_steps(ctx), Orchid.Scheduler.done?(ctx)} do
      {[], true} ->
        {:done, ctx}

      {[], false} ->
        {:stuck, ctx}

      {[{step, idx} | _], _} ->
        case Orchid.Runner.run(step, ctx.params, ctx.recipe.opts, ctx.workflow_ctx) do
          # List(Params), Tuple(Params) & Param
          {:ok, result}
          when is_list(result) or is_tuple(result) or is_struct(result, Orchid.Param) ->
            {:cont, Orchid.Scheduler.merge_result(ctx, idx, result)}

          {:special, result} ->
            {:error,
             %Orchid.Error{
               reason: {:core_executor_not_support_special, result},
               context: ctx,
               step_id: Orchid.Step.ID.finger_print(step),
               kind: :exception
             }}

          {:error, reason} ->
            {:error,
             %Orchid.Error{
               reason: reason,
               context: ctx,
               step_id: Orchid.Step.ID.finger_print(step),
               kind: :exception
             }}
        end
    end
  end
end
