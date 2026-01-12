defmodule Orchid.Pipeline do
  @doc "Run pipeline at request level(not step)."
  alias Orchid.Operon.{Request, Response}

  @spec run([module()], Request.t()) :: Response.t()
  def run(stack, request), do: dispatch(stack, request)

  defp dispatch([], _req), do: build_err(:no_sink_middleware)
  defp dispatch([sink], req), do: sink.call(req, fn _ -> build_err(:reached_sink_end) end)
  defp dispatch([operon | rest], req), do: operon.call(req, &dispatch(rest, &1))

  defp build_err(reason), do: %Response{payload: {:error, %Orchid.Error{reason: reason}}}
end
