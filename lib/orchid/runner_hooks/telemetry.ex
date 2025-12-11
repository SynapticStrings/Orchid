defmodule Orchid.Runner.Hooks.Telemetry do
  @behaviour Orchid.Runner.Hook

  @spec call(Orchid.Runner.Context.t(), Orchid.Runner.Hook.next_fn()) ::
          {:ok, Orchid.Step.output()} | {:error, term()}
  def call(ctx, next) do
    meta = ctx.telemetry_meta
    :telemetry.execute([:orchid, :step, :start], %{system_time: System.system_time()}, meta)
    start_time = System.monotonic_time()

    # --- 执行后续管道 (包含 Validator, Executor 等) ---
    try do
      case next.(ctx) do
        {:ok, result} ->
          duration = System.monotonic_time() - start_time
          :telemetry.execute([:orchid, :step, :stop], %{duration: duration}, meta)
          {:ok, result}

        {:error, reason} ->
          report_error(start_time, meta, reason)
          {:error, reason}
      end
    rescue
      # 开发时记得注册 Linster
      e ->
        stack = __STACKTRACE__
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:orchid, :step, :exception],
          %{duration: duration},
          Map.merge(meta, %{kind: :error, reason: e, stacktrace: stack})
        )

        {:error, e}
    catch
      kind, reason ->
        duration = System.monotonic_time() - start_time

        :telemetry.execute(
          [:orchid, :step, :exception],
          %{duration: duration},
          Map.merge(meta, %{kind: kind, reason: reason})
        )

        {:error, {kind, reason}}
    end
  end

  defp report_error(start_time, meta, reason) do
    duration = System.monotonic_time() - start_time

    :telemetry.execute(
      [:orchid, :step, :exception],
      %{duration: duration},
      Map.put(meta, :reason, reason)
    )
  end
end
