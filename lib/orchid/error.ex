defmodule Orchid.Error do
  @type t :: %__MODULE__{
          reason: term(),
          context: Orchid.Scheduler.Context.t() | nil,
          step_id: Orchid.Step.ID.t() | Orchid.Step.t() | nil,
          kind: :logic | :exception | :exit
        }
  defexception [:reason, :context, :step_id, :kind]

  @impl true
  def message(%__MODULE__{reason: reason, step_id: step_id, kind: kind}) do
    step =
      case step_id do
        nil -> "during running"
        step_id -> "at step #{inspect(step_id)}"
      end

    "Orchid execution failed #{step} (#{kind}): #{inspect(reason)}"
  end
end
