defmodule Orchid.Executor do
  @moduledoc """
  Executor behavoir.

  An executor receive a `Orchid.Scheduler.Context` struct and do execution.
  """

  @type executor :: module()
  @type executor_opts :: keyword()

  @type response :: {:ok, Orchid.Scheduler.Context.param_map()} | {:error, term()}

  @callback execute(Orchid.Scheduler.Context.t(), executor_opts()) ::
              response()
end
