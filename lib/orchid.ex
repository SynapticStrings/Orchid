defmodule Orchid do
  @moduledoc """
  编辑器的核心代码以及业务逻辑。

  旨在实现一个便于扩展和定制的任务执行框架。

  """

  @doc """
  执行。

  ### Options

  * `:return_response` - 以 `Orchid.Operon.Response` 返回，默认为 false
  * `:operons_stack` - 其他操作子（Recipe 层面的 hook）的堆栈，有先后顺序
  """
  @spec run(Orchid.Recipe.t(), Orchid.Scheduler.initial_params(), keyword()) ::
          Orchid.Operon.Response.payload() | Orchid.Operon.Response.t()
  def run(recipe, input_params, opts \\ []) do
    response? = Keyword.get(opts, :return_response, false)
    operons_stack = Keyword.get(opts, :operons_stack, [])

    response =
      Orchid.Pipeline.run(
        operons_stack ++ [Orchid.Operon.Execute],
        %Orchid.Operon.Request{
          recipe: recipe,
          inital_params: input_params
        }
      )

    if response? do
      response
    else
      response.payload
    end
  end
end
