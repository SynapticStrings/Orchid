defmodule QyCore.Executor do
  @type executor :: module()
  @type executor_opts :: keyword()

  @type response :: {:ok, [QyCore.Param.t()]} | {:error, term()}

  @callback execute(QyCore.Scheduler.Context.t(), executor_opts()) ::
              response()
end
