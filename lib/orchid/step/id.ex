defmodule Orchid.Step.ID do
  @moduledoc """
  Create identifier/fingerprint via Step's input, output or mapper in option.
  """
  alias Orchid.Step

  @type t :: integer() | Step.step_schema() | :root

  @spec finger_print(Step.t(), headless? :: boolean()) :: t()
  def finger_print(step, headless? \\ true)

  def finger_print({impl, in_k, out_k, _opts}, headless?),
    do: finger_print({impl, in_k, out_k}, headless?)

  def finger_print({_impl, in_k, out_k}, true) do
    {normalize_keys_to_set(in_k), normalize_keys_to_set(out_k)}
  end

  def finger_print({impl, in_k, out_k}, false) do
    {impl, normalize_keys_to_set(in_k), normalize_keys_to_set(out_k)}
  end

  @doc """
  Check if two steps have the same input and output keys.
  """
  @spec same?(Step.t(), Step.t()) :: boolean()
  def same?(step1, step2) do
    {i1, o1} = finger_print(step1, true)
    {i2, o2} = finger_print(step2, true)

    MapSet.equal?(i1, i2) and MapSet.equal?(o1, o2)
  end

  @doc """
  normalize step's io key into MapSet.
  """
  @spec normalize_keys_to_set(nil | atom() | list() | tuple() | MapSet.t()) :: MapSet.t()
  def normalize_keys_to_set(nil), do: MapSet.new()
  def normalize_keys_to_set(atom) when is_atom(atom), do: MapSet.new([atom])
  def normalize_keys_to_set(list) when is_list(list), do: MapSet.new(list)
  def normalize_keys_to_set(tuple) when is_tuple(tuple), do: MapSet.new(Tuple.to_list(tuple))
  def normalize_keys_to_set(mapset), do: mapset
end
