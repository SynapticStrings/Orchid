defmodule Orchid.Pipeline do
  @doc """
  Run pipeline
  """
  @spec run([module()], Orchid.Operon.Request.t()) ::
          Orchid.Operon.Response.t() | {:error, term()}
  def run(stack, request), do: dispatch(stack, request)

  defp dispatch([], _req), do: {:error, :no_sink_middleware}
  defp dispatch([sink], req), do: sink.call(req, fn _ -> {:error, :reached_sink_end} end)
  defp dispatch([operon | rest], req), do: operon.call(req, &dispatch(rest, &1))
end
