defmodule QyCore.Param do
  @moduledoc """
  关于序列参数的相关模块。

  设计该模块的目的是实现一系列和参数有关的逻辑以及定义一系列的接口以帮助或约束其他使用 `qy_core`
  的开发者使其更专注业务逻辑。
  """

  @type t :: %__MODULE__{
          name: name(),
          type: param_type(),
          payload: payload(),
          metadata: map()
        }
  defstruct [
    :name,
    :type,
    :payload,
    metadata: %{}
  ]

  ## 类型

  @type name :: term()
  @type param_type :: atom() | module()
  @type ref_payload :: {:ref, module() | pid(), term()}
  @type raw_payload :: any() | nil
  @type payload :: raw_payload() | ref_payload()

  ## 函数

  @spec new(name(), param_type(), payload(), %{}) :: t()
  def new(name, type, payload \\ nil, metadata \\ %{}) do
    %__MODULE__{
      name: name,
      type: type,
      payload: payload,
      metadata: metadata
    }
  end

  def get_payload(%__MODULE__{payload: payload}), do: payload

  @spec set_payload(t(), payload()) :: t()
  def set_payload(%__MODULE__{} = param, new_payload) do
    %__MODULE__{param | payload: new_payload}
  end

  # metadata 相关函数后续添加
end
