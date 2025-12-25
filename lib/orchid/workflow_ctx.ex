defmodule Orchid.WorkflowCtx do
  @type t :: %__MODULE__{
    root_id: any(),
    path: [Orchid.Step.ID.t()],
    baggage: %{},
    config: %{}
  }
  defstruct [:root_id, path: [:root], baggage: %{}, config: %{}]

  def new() do
    %__MODULE__{}
  end

  def add_step(%__MODULE__{path: path} = ctx, step_id), do: %{ctx | path: path ++ [step_id]}
end
