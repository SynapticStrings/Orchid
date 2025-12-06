defmodule QyCore.Pipeline do
  @doc """
  运行管道。
  """
  def run(stack, request) do
    dispatch(stack, request)
  end

  defp dispatch([], _req), do: {:error, :no_sink_middleware}

  defp dispatch([sink], req) do
    sink.call(req, fn _ -> {:error, :reached_sink_end} end)
  end

  defp dispatch([operon | rest], req) do
    operon.call(req, &dispatch(rest, &1))
  end
end
