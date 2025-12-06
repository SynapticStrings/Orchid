defmodule QyCore.Runner do
  import QyCore.Utilities, only: [ensure_full_step: 1]

  @spec run(
          QyCore.Recipe.Step.t(),
          any(),
          keyword()
        ) :: {:ok, QyCore.Recipe.Step.output()} | {:error, term()}
  def run(step, ctx_params, recipe_opts) do
    {impl, in_keys, out_keys, step_opts} = ensure_full_step(step)

    initial_ctx = %{
      step_implementation: impl,
      in_keys: in_keys,
      out_keys: out_keys,
      step_default_opts: step_opts,
      inputs: prepare_inputs(in_keys, ctx_params),
      recipe_opts: recipe_opts,
      telemetry_meta: %{impl: impl, in_keys: in_keys, out_keys: out_keys},

      # 参照了 LiveView.Socket ，后面忘了
      assigns: %{}
    }

    hook_stack =
      [QyCore.Runner.Hooks.Telemetry] ++
        Keyword.get(step_opts, :extra_hook_stack, []) ++
        [QyCore.Runner.Hooks.Core]

    run_pipeline(hook_stack, initial_ctx)
  end

  # 递归执行管道
  defp run_pipeline([], _ctx), do: {:error, :no_executor_plugin}

  # 需要注意的是，最后一个中间件不需要 next 参数
  defp run_pipeline([plug | rest], ctx) do
    next_fn = fn next_ctx -> run_pipeline(rest, next_ctx) end
    plug.call(ctx, next_fn)
  end

  defp prepare_inputs(keys, params) when is_list(keys),
    do: Enum.map(keys, &Map.fetch!(params, &1))

  defp prepare_inputs(keys, params) when is_tuple(keys),
    do: Enum.map(Tuple.to_list(keys), &Map.fetch!(params, &1))

  # Let it crash.
  defp prepare_inputs(key, params) when is_map(params), do: Map.fetch!(params, key)
end
