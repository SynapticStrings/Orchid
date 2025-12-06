defmodule QyCore.Utilities do
  # 这些函数没有特别复杂，将来搞一下 doctest 也是可以的

  @doc """
  标准化步骤的输入输出键为 MapSet。
  """
  @spec normalize_keys_to_set(nil | atom() | list() | tuple() | MapSet.t()) :: MapSet.t()
  def normalize_keys_to_set(nil), do: MapSet.new()
  def normalize_keys_to_set(atom) when is_atom(atom), do: MapSet.new([atom])
  def normalize_keys_to_set(list) when is_list(list), do: MapSet.new(list)
  def normalize_keys_to_set(tuple) when is_tuple(tuple), do: MapSet.new(Tuple.to_list(tuple))
  def normalize_keys_to_set(mapset), do: mapset

  @doc """
  辅助：规范化 Step 结构，支持多种形式的 Step 定义。
  """
  @spec ensure_full_step(
          QyCore.Recipe.Step.step_schema()
          | QyCore.Recipe.Step.step_with_options()
        ) :: QyCore.Recipe.Step.step_with_options()
  def ensure_full_step({impl, in_k, out_k}), do: {impl, in_k, out_k, []}
  def ensure_full_step({impl, in_k, out_k, opts}), do: {impl, in_k, out_k, opts}
end
