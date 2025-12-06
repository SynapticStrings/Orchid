defmodule QyCore.Executor do
  @callback execute(QyCore.Recipe.t(), [QyCore.Param.t()], executor_opts :: keyword()) ::
              {:ok, [QyCore.Param.t()]} | {:error, term()}
end
