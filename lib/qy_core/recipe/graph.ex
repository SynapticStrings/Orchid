defmodule QyCore.Recipe.Graph do
  @moduledoc """
  负责分析 Recipe 的拓扑结构，主要进行静态检查。
  """

  alias QyCore.Step

  def check_missing_initial(steps, initial_keys) do
    indexed_steps = build_initial_steps(steps)

    all_produced_keys =
      Enum.reduce(indexed_steps, MapSet.new(initial_keys), fn s, acc ->
        MapSet.union(acc, s.provides)
      end)

    missing_inputs =
      Enum.reduce(indexed_steps, %{}, fn step, acc ->
        missing = MapSet.difference(step.needed, all_produced_keys)

        if MapSet.size(missing) > 0 do
          Map.put(acc, step.index, MapSet.to_list(missing))
        else
          acc
        end
      end)

    case map_size(missing_inputs) do
      0 -> :ok
      _ -> {:error, {:missing_inputs, missing_inputs}}
    end
  end

  def check_cycles(steps, available) do
    # 这里的逻辑类似 Kahn 算法
    # 只要能找到依赖满足的节点，就将其移出列表，并将其产出加入 available
    # 如果列表不为空但找不到可运行节点，剩下的就是环
    case run_simulation(build_initial_steps(steps), normalize_keys_to_set(available)) do
      [] ->
        :ok

      remaining_steps ->
        # 剩下的步骤构成了环（或者互相等待）
        cyclic_indices = Enum.map(remaining_steps, & &1.step)
        {:error, {:cyclic, cyclic_indices}}
    end
  end

  defp build_initial_steps(steps) do
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
  end

  defp run_simulation([], _available), do: []

  defp run_simulation(pending, available) do
    {ready, not_ready} =
      Enum.split_with(pending, fn %{needed: needed} ->
        MapSet.subset?(needed, available)
      end)

    case ready do
      [] ->
        # 没有任何步骤准备好，死锁
        pending

      _ ->
        newly_produced =
          ready
          |> Enum.map(& &1.provides)
          |> Enum.reduce(MapSet.new(), &MapSet.union/2)

        new_available = MapSet.union(available, newly_produced)
        run_simulation(not_ready, new_available)
    end
  end

  @doc """
  标准化步骤的输入输出键为 MapSet。
  """
  @spec normalize_keys_to_set(nil | atom() | list() | tuple() | MapSet.t()) :: MapSet.t()
  def normalize_keys_to_set(nil), do: MapSet.new()
  def normalize_keys_to_set(atom) when is_atom(atom), do: MapSet.new([atom])
  def normalize_keys_to_set(list) when is_list(list), do: MapSet.new(list)
  def normalize_keys_to_set(tuple) when is_tuple(tuple), do: MapSet.new(Tuple.to_list(tuple))
  def normalize_keys_to_set(mapset), do: mapset
end
