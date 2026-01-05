defmodule Orchid.WorkflowCtx do
  @moduledoc """
  Represents the context of a workflow execution, including its configuration,
  path, and baggage.
  """
  @type t :: %__MODULE__{
          root_id: any(),
          path: [Orchid.Step.ID.t()],
          baggage: %{},
          config: %{}
        }
  defstruct [:root_id, path: [:root], baggage: %{}, config: %{}]

  def new(), do: %__MODULE__{}

  def get_config(ctx, key, default \\ nil), do: Map.get(ctx.config, key, default)

  def merge_config(ctx, new_opts),
    do: ctx.config |> Map.merge(Enum.into(new_opts, %{})) |> then(&%{ctx | config: &1})

  def get_baggage(ctx, key, default \\ nil), do: Map.get(ctx.baggage, key, default)

  def merge_baggage(ctx, baggage),
    do: ctx.baggage |> Map.merge(Enum.into(baggage, %{})) |> then(&%{ctx | baggage: &1})

  def add_depth(%__MODULE__{path: path} = ctx, step_id), do: %{ctx | path: path ++ [step_id]}
end
