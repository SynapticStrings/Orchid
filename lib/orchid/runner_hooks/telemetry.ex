defmodule Orchid.Runner.Hooks.Telemetry do
  @behaviour Orchid.Runner.Hook

  @spec call(Orchid.Runner.Context.t(), Orchid.Runner.Hook.next_fn()) ::
          {:ok, Orchid.Step.output()} | {:error, term()}
  def call(ctx, next) do
    meta = ctx.telemetry_meta
    :telemetry.execute([:orchid, :step, :start], %{system_time: System.system_time()}, meta)
    start_time = System.monotonic_time()

    # --- Execute inner pipes(include validator, executor etc.) ---
    try do
      case next.(%{
             ctx
             | step_opts: Keyword.put(ctx.step_opts, :__reporter_ctx__, ctx.telemetry_meta)
           }) do
        {:ok, result} ->
          duration = System.monotonic_time() - start_time
          :telemetry.execute([:orchid, :step, :stop], %{duration: duration}, meta)

          {:ok, result}

        {:error, reason} ->
          # report_error(start_time, meta, :failed, reason)
          report_error(start_time, Map.put(meta, :reason, reason))

          {:error, reason}
      end
    rescue
      # Remember register linster durign development
      e ->
        # report_error(start_time, meta, :rescue, {e, __STACKTRACE__})
        report_error(start_time, Map.merge(meta, %{kind: :error, reason: e, stacktrace: __STACKTRACE__}))

        {:error, e}
    catch
      kind, reason ->
        # report_error(start_time, meta, :catch, {kind, reason})
        report_error(start_time, Map.merge(meta, %{kind: kind, reason: reason}))

        {:error, {kind, reason}}
    end
  end

  defp report_error(start_time, payload) do
    :telemetry.execute(
      [:orchid, :step, :exception],
      %{duration: System.monotonic_time() - start_time},
      payload
    )
  end
end
