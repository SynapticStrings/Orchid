defmodule QyCore do
  @moduledoc """
  编辑器的核心代码以及业务逻辑。

  旨在实现一个通用的编辑器框架的基础设施，以便于扩展和定制。
  """

  @doc """
  运行。
  """
  @spec run(QyCore.Recipe.t(), QyCore.Scheduler.initial_params(), keyword()) ::
          QyCore.Operon.Responce.payload()
  def run(recipe, input_params, _opts \\ []) do
    operons = [QyCore.Operon.Execute]

    req = %QyCore.Operon.Request{
      recipe: recipe,
      inital_param: input_params
    }

    QyCore.Pipeline.run(operons, req).payload
  end
end
