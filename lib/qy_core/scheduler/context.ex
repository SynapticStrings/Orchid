defmodule QyCore.Scheduler.Context do
  alias QyCore.{Param, Step, Recipe}

  @type param_map :: %{optional(atom()) => Param.t()}
  @type t :: %__MODULE__{
          recipe: Recipe.t(),
          pending_steps: [{Step.t(), non_neg_integer()}],
          available_keys: MapSet.t(Step.io_key()),
          params: param_map(),
          running_steps: MapSet.t(Step.t()),
          history: [{non_neg_integer(), param_map() | [Param.t()] | Param.t()}],
          assings: %{any() => any()}
        }
  defstruct [
    # Recipe 本体
    # 用于 Executor 使用（为了保持一致性，不允许做修改）
    :recipe,
    ## 原始 QyCore
    # 还未执行的步骤列表
    :pending_steps,
    # 当前已有的数据 keys
    :available_keys,
    # 实际数据本体
    :params,
    # 正在运行中的 steps
    :running_steps,
    # 执行历史
    :history,
    ## 可能的其他上下文
    :assings
  ]
end
