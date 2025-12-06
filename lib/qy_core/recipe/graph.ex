defmodule QyCore.Recipe.Graph do
  @moduledoc """
  负责分析 Recipe 的拓扑结构，计算执行顺序，并进行静态检查。
  """

  alias QyCore.Recipe.Step
  import QyCore.Utilities, only: [normalize_keys_to_set: 1]

  @spec validate([Step.t()], Step.input_keys()) ::
          :ok | {:error, {:missing_inputs, non_neg_integer(), [Step.input_keys()]}}
  def validate(steps, initial_keys) do
    # 确保 initial_keys 是 MapSet
    available = MapSet.new(initial_keys)

    # 预处理 Steps，规范化 Keys
    indexed_steps =
      steps
      |> Enum.with_index()
      |> Enum.map(fn {step, idx} ->
        {_impl, in_k, out_k} = Step.extract_schema(step)

        %{
          index: idx,
          step: step,
          needed: normalize_keys_to_set(in_k),
          provides: normalize_keys_to_set(out_k)
        }
      end)

    case simulate_run(indexed_steps, available) do
      :ok -> :ok
      {:error, reason} -> {:error, reason}
    end
  end

  defp simulate_run([], _available), do: :ok

  defp simulate_run(pending, available) do
    # 核心逻辑：找出所有需求被满足的步骤
    {ready, not_ready} =
      Enum.split_with(pending, fn %{needed: needed} ->
        MapSet.subset?(needed, available)
      end)

    case ready do
      [] ->
        first_stuck = hd(pending)
        missing = MapSet.difference(first_stuck.needed, available) |> MapSet.to_list()
        {:error, {:missing_inputs, first_stuck.index, missing}}

      _ ->
        newly_produced =
          ready
          |> Enum.map(& &1.provides)
          |> Enum.reduce(MapSet.new(), &MapSet.union/2)

        new_available = MapSet.union(available, newly_produced)
        simulate_run(not_ready, new_available)
    end
  end
end
