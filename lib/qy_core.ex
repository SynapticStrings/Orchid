defmodule QyCore do
  @moduledoc """
  编辑器的核心代码以及业务逻辑。

  旨在实现一个通用的编辑器框架的基础设施，以便于扩展和定制。
  """

  @doc """
  运行。
  """
  def run(recipe, input_params, maybe_options_with_executor \\ [])

  def run(recipe, input_params, {adapter, adapter_options}) when is_atom(adapter) do
    adapter.execute(recipe, input_params, adapter_options)
  end

  def run(recipe, input_params, adapter_options) do
    QyCore.Executor.Serial.execute(recipe, input_params, adapter_options)
  end
end
