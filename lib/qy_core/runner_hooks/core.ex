defmodule QyCore.Runner.Hooks.Core do
  @behaviour QyCore.Runner.Hook

  alias QyCore.Param

  def call(ctx, _next) do
    # 构造 Reporter
    reporter_fn = fn progress, payload ->
      :telemetry.execute(
        [:qy_core, :step, :progress],
        %{progress: progress},
        Map.merge(ctx.telemetry_meta, %{payload: payload})
      )
    end

    # 注入资源
    final_opts =
      ctx.step_default_opts
      |> Keyword.merge(ctx.recipe_opts)
      |> Keyword.put(:__reporter__, reporter_fn)

    case run_step(ctx.step_implementation, ctx.inputs, final_opts) do
      {:ok, raw_output} ->
        renamed = align_output_names(raw_output, ctx.out_keys)
        {:ok, renamed}

      other ->
        other
    end
  end

  defp align_output_names(%Param{} = param, out_key) when is_atom(out_key) do
    %{param | name: out_key}
  end

  defp align_output_names(params, out_keys) when is_list(params) do
    keys = List.wrap(out_keys)
    Enum.zip_with(params, keys, fn param, key -> %{param | name: key} end)
  end

  defp align_output_names(%Param{} = param, [out_key]) do
    [%{param | name: out_key}]
  end

  defp align_output_names(param, out_key) when is_tuple(param) do
    align_output_names(Tuple.to_list(param), Tuple.to_list(out_key))
  end

  defp run_step(impl, inputs, opts) when is_atom(impl) do
    if Code.ensure_loaded?(impl) and function_exported?(impl, :run, 2) do
      impl.run(inputs, opts)
    else
      {:error, {:invalid_step_implementation, impl}}
    end
  end

  defp run_step(run_fun, inputs, opts) when is_function(run_fun, 2) do
    run_fun.(inputs, opts)
  end

  defp run_step(_, _, _), do: {:error, :invalid_step_implementation}
end
