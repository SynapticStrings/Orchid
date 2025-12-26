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
    :erlang.phash2({impl, normalize_key(in_k), normalize_key(out_k)})
  end

  def finger_print({impl, in_k, out_k}, false) do
    {impl, normalize_key(in_k), normalize_key(out_k)}
  end

  defp normalize_key(k) when is_atom(k), do: MapSet.new([k])
  defp normalize_key(k) when is_tuple(k), do: Tuple.to_list(k)
  defp normalize_key(k) when is_list(k), do: MapSet.new(k)
end
