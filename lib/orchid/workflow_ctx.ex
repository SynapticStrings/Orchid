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

  def get_config(ctx, key, default \\ nil) do
    Map.get(ctx.config, key, default)
  end

  def merge_config(ctx, new_opts) do
    new_config = Map.merge(ctx.config, Enum.into(new_opts, %{}))
    %{ctx | config: new_config}
  end

  def merge_baggage(ctx, baggage) do
    %{ctx | baggage: Map.merge(ctx.baggage, Enum.into(baggage, %{}))}
  end

  def add_step(%__MODULE__{path: path} = ctx, step_id), do: %{ctx | path: path ++ [step_id]}
end
