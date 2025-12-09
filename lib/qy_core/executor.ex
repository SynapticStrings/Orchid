defmodule QyCore.Executor do
  # TODO: 解耦 Scheduler 和 Executor 具体实现的关系。

  @type executor :: module()
  @type executor_opts :: keyword()

  @type responce :: {:ok, [QyCore.Param.t()]} | {:error, term()}

  @callback execute(QyCore.Recipe.t(), QyCore.Scheduler.initial_params(), executor_opts()) :: responce()
end
