defmodule QyCore.Executor do
  @type executor :: module()
  @type executor_opts :: keyword()

  @callback execute(QyCore.Recipe.t(), [QyCore.Param.t()], executor_opts()) ::
              {:ok, [QyCore.Param.t()]} | {:error, term()}
end
