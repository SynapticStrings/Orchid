defmodule Orchid.Step.ID do
  @moduledoc """
  Create identifier/fingerprint via Step's input, output or mapper in option.
  """
  alias Orchid.Step

  @type t :: integer() | Step.step_schema() | :root

  @spec finger_print(Orchid.Step.t(), as_num? :: boolean()) :: t()
  def finger_print(step, as_num? \\ false)

  def finger_print({impl, in_k, out_k, _opts}, as_num?),
    do: finger_print({impl, in_k, out_k}, as_num?)

  def finger_print({impl, in_k, out_k}, true) do
    :erlang.phash2({impl, normalize_keys_to_set(in_k), normalize_keys_to_set(out_k)})
  end

  def finger_print({impl, in_k, out_k}, false) do
    {impl, normalize_keys_to_set(in_k), normalize_keys_to_set(out_k)}
  end

  @doc """
  normalize step's io key into MapSet。
  """
  @spec normalize_keys_to_set(nil | atom() | list() | tuple() | MapSet.t()) :: MapSet.t()
  def normalize_keys_to_set(nil), do: MapSet.new()
  def normalize_keys_to_set(atom) when is_atom(atom), do: MapSet.new([atom])
  def normalize_keys_to_set(list) when is_list(list), do: MapSet.new(list)
  def normalize_keys_to_set(tuple) when is_tuple(tuple), do: MapSet.new(Tuple.to_list(tuple))
  def normalize_keys_to_set(mapset), do: mapset
end
