defmodule QyCore.Scheduler.Context do
  alias QyCore.{Param, Recipe}

  @type param_map :: %{optional(atom()) => Param.t()}
  @type t :: %__MODULE__{
          pending_steps: [Recipe.Step.t()],
          available_keys: MapSet.t(Recipe.Step.io_key()),
          params: param_map(),
          running_steps: MapSet.t(Recipe.Step.t()),
          history: [{non_neg_integer(), param_map()}]
        }
  defstruct [
    ## 调度
    # 还未执行的步骤列表 [{step, idx}]
    :pending_steps,
    # 当前已有的数据 keys (MapSet<Atom>)
    :available_keys,
    # 实际数据 (Map<Name, Param>)
    :params,
    # 正在运行中的 steps (用于并行控制)
    :running_steps,
    # 执行历史 [{step_idx, output_params}]
    :history
  ]
end
