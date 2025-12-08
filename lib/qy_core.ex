defmodule QyCore do
  @moduledoc """
  编辑器的核心代码以及业务逻辑。

  旨在实现一个便于扩展和定制的任务执行框架。
  """

  @doc """
  执行。
  """
  @spec run(QyCore.Recipe.t(), QyCore.Scheduler.initial_params(), keyword()) ::
          QyCore.Operon.Responce.payload() | QyCore.Operon.Responce.t()
  def run(recipe, input_params, opts \\ []) do
    responce? = Keyword.get(opts, :return_responce, false)
    operons_stack = Keyword.get(opts, :operons_stack, [])

    responce =
      QyCore.Pipeline.run(
        operons_stack ++ [QyCore.Operon.Execute],
        %QyCore.Operon.Request{
          recipe: recipe,
          inital_param: input_params
        }
      )

    if responce? do
      responce
    else
      responce.payload
    end
  end
end
