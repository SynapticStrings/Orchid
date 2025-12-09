defmodule QyCore.Executor do
  @type executor :: module()
  @type executor_opts :: keyword()

  @type responce :: {:ok, [QyCore.Param.t()]} | {:error, term()}

  @callback execute(QyCore.Recipe.t(), QyCore.Scheduler.initial_params(), executor_opts()) ::
              responce()
end
