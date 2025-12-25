defmodule Orchid.Step.ID do
  @moduledoc """
  Create identifier/fingerprint via Step's input, output or mapper in option.
  """

  def finger_print({impl, in_k, out_k, _opts}), do: finger_print({impl, in_k, out_k})
  def finger_print({impl, in_k, out_k}) do
    :erlang.phash2({impl, normalize_key(in_k), normalize_key(out_k)})
  end

  defp normalize_key(k) when is_atom(k), do: MapSet.new([k])
  defp normalize_key(k) when is_tuple(k), do: Tuple.to_list(k)
  defp normalize_key(k) when is_list(k), do: MapSet.new(k)
end
