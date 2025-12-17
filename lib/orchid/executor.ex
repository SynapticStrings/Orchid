defmodule Orchid.Executor do
  @moduledoc """
  Executor behavoir.

  An executor receive a `Orchid.Scheduler.Context` struct and do execution.

  There're some functions recommend to use during execution.

  * `Orchid.Scheduler.next_ready_steps/1`
  * `Orchid.Scheduler.merge_result/2`
  * `Orchid.Scheduler.mark_running_steps/3`
  """

  @type executor :: module()
  @type executor_opts :: keyword()

  @type response :: {:ok, Orchid.Scheduler.Context.param_map()} | {:error, term()}

  @callback execute(Orchid.Scheduler.Context.t(), executor_opts()) ::
              response()
end
