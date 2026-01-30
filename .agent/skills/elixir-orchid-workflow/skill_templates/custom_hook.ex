# Template: Authorization + Logging Hook
defmodule MyApp.Hooks.SecureStep do
  @behaviour Orchid.Runner.Hook
  require Logger

  @impl true
  def call(ctx, next) do
    # PRE-EXECUTION: Check authorization
    case check_permission(ctx) do
      :ok ->
        Logger.info("Executing step",
          step: ctx.step_implementation,
          request_id: get_request_id(ctx)
        )

        start_time = System.monotonic_time()

        # EXECUTE
        result = next.(ctx)

        duration_ms = System.monotonic_time() - start_time |> div(1_000_000)

        case result do
          {:ok, output} ->
            Logger.info("Step succeeded",
              step: ctx.step_implementation,
              duration_ms: duration_ms
            )
            {:ok, output}

          {:error, reason} ->
            Logger.warning("Step failed",
              step: ctx.step_implementation,
              reason: inspect(reason),
              duration_ms: duration_ms
            )
            {:error, reason}
        end

      {:error, reason} ->
        Logger.warning("Authorization denied",
          step: ctx.step_implementation,
          reason: reason
        )
        {:error, {:unauthorized, reason}}
    end
  end

  defp check_permission(ctx) do
    user_role = Orchid.WorkflowCtx.get_baggage(ctx.workflow_ctx, :user_role, :guest)

    restricted_steps = [
      MyApp.Steps.DeleteData,
      MyApp.Steps.ModifySchema
    ]

    if ctx.step_implementation in restricted_steps and user_role != :admin do
      {:error, "admin_required"}
    else
      :ok
    end
  end

  defp get_request_id(ctx) do
    Orchid.WorkflowCtx.get_baggage(ctx.workflow_ctx, :request_id, "unknown")
  end
end

# ============================================
# Template: Caching Hook
# ============================================

defmodule MyApp.Hooks.CacheStep do
  @behaviour Orchid.Runner.Hook

  @impl true
  def call(ctx, next) do
    cache_key = make_cache_key(ctx)

    case get_cache(cache_key) do
      {:ok, cached_result} ->
        # Return cached without executing
        {:ok, cached_result}

      :miss ->
        # Execute and cache
        case next.(ctx) do
          {:ok, result} ->
            put_cache(cache_key, result)
            {:ok, result}

          error ->
            error
        end
    end
  end

  defp make_cache_key(ctx) do
    {
      ctx.step_implementation,
      Enum.sort(ctx.inputs),
      Enum.sort(ctx.step_opts)
    }
    |> :erlang.phash2()
  end

  defp get_cache(key), do: MyApp.Cache.get(key)
  defp put_cache(key, val), do: MyApp.Cache.put(key, val)
end
