defmodule Orchid.Runner.Hooks.Telemetry do
  @behaviour Orchid.Runner.Hook
  require Logger

  @spec call(Orchid.Runner.Context.t(), Orchid.Runner.Hook.next_fn()) ::
          Orchid.Runner.Hook.hook_result()
  def call(ctx, next) do
    meta = ctx.telemetry_meta
    :telemetry.execute([:orchid, :step, :start], %{system_time: System.system_time()}, meta)
    start_time = System.monotonic_time()
    final_ctx = %{ctx | step_opts: Keyword.put(ctx.step_opts, :__reporter_ctx__, meta)}

    try do
      case next.(final_ctx) do
        {:ok, result} ->
          duration = System.monotonic_time() - start_time
          :telemetry.execute([:orchid, :step, :done], %{duration: duration}, meta)

          {:ok, result}

        {:special, result} ->
          duration = System.monotonic_time() - start_time
          meta = Map.put(meta, :special, result)
          :telemetry.execute([:orchid, :step, :special], %{duration: duration}, meta)

          {:special, result}

        {:error, reason} ->
          report_error(start_time, Map.put(meta, :reason, reason))

          {:error, reason}
      end
    rescue
      # Remember register linster durign development
      e ->
        report_error(
          start_time,
          Map.merge(meta, %{kind: :error, reason: e, stacktrace: __STACKTRACE__})
        )

        {:error, e}
    catch
      kind, reason ->
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

  @doc """
  A helper error handler for Telemetry step exceptions.

  When you want to log step exceptions, you can attach this handler to the
  `[:orchid, :step, :exception]` event.

  ### Example

      # In iex.exs or your application startup
      :telemetry.attach(
        "orchid-step-exception-logger",
        [:orchid, :step, :exception],
        &Orchid.Runner.Hooks.Telemetry.error_handler/4,
        %{}
      )
  """
  def error_handler([:orchid, :step, :exception], _measurements, meta, _config) do
    details =
      if meta[:stacktrace] do
        "Reason: #{inspect(meta[:reason])}\nStacktrace:\n" <>
          Exception.format_stacktrace(meta.stacktrace)
      else
        "Kind: #{meta[:kind]}\nReason: #{inspect(meta[:reason])}"
      end

    Logger.error("""
    [Orchid] Step Exception Captured!
    Step: #{inspect(meta[:impl])} with inputs #{inspect(meta[:in_keys])} and outputs #{inspect(meta[:out_keys])}
    #{details}
    """)
  end
end
