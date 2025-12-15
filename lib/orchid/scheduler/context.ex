defmodule Orchid.Scheduler.Context do
  alias Orchid.{Param, Step, Recipe}

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
    # Recipe
    # Used for Executor
    # edit is not allowed for consistency
    :recipe,
    ## Origin Orchid
    # steps where not executed
    :pending_steps,
    # keys we have
    :available_keys,
    # actual datas
    :params,
    # running steps
    :running_steps,
    # execution history
    :history,
    ## other context
    :assings
  ]
end
