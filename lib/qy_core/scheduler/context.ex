defmodule QyCore.Scheduler.Context do
  alias QyCore.{Param, Recipe}

  @type param_map :: %{optional(atom()) => Param.t()}
  @type t :: %__MODULE__{
          pending_steps: [{Recipe.Step.t(), non_neg_integer()}],
          available_keys: MapSet.t(Recipe.Step.io_key()),
          params: param_map(),
          running_steps: MapSet.t(Recipe.Step.t()),
          history: [{non_neg_integer(), param_map() | [Param.t()] | Param.t()}]
        }
  defstruct [
    ## 调度
    # 还未执行的步骤列表
    :pending_steps,
    # 当前已有的数据 keys
    :available_keys,
    # 实际数据本体
    :params,
    # 正在运行中的 steps
    :running_steps,
    # 执行历史
    :history
  ]
end
