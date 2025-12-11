defmodule Orchid.Executor do
  @moduledoc """
  Executor behavoir.
  """

  @type executor :: module()
  @type executor_opts :: keyword()

  @type response :: {:ok, [Orchid.Param.t()]} | {:error, term()}

  @callback execute(Orchid.Scheduler.Context.t(), executor_opts()) ::
              response()
end
