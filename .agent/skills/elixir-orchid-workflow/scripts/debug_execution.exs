#!/usr/bin/env elixir
# Usage: elixir debug_execution.exs
# Attach telemetry and step-by-step debugging

defmodule DebugExecution do
  require Logger

  def enable_telemetry do
    # Log every step
    :telemetry.attach("orchid-debug-start", [:orchid, :step, :start],
      fn event, measurements, meta ->
        IO.puts("\n🚀 STEP START: #{meta.impl}")
        IO.puts("   Inputs: #{inspect(meta.in_keys)}")
      end, nil)

    # Log completion
    :telemetry.attach("orchid-debug-done", [:orchid, :step, :done],
      fn event, measurements, meta ->
        duration_ms = measurements.duration / 1_000_000
        IO.puts("✅ STEP DONE: #{meta.impl} (#{duration_ms}ms)")
      end, nil)

    # Log exceptions
    :telemetry.attach("orchid-debug-exception", [:orchid, :step, :exception],
      fn event, measurements, meta ->
        IO.puts("\n❌ STEP EXCEPTION: #{meta.impl}")
        IO.puts("   Reason: #{inspect(meta.reason)}")
      end, nil)

    # Log progress
    :telemetry.attach("orchid-debug-progress", [:orchid, :step, :progress],
      fn event, measurements, meta ->
        IO.puts("   ⏳ Progress: #{meta.progress} - #{inspect(meta.payload)}")
      end, nil)
  end

  def run_with_debug(recipe, initial_params, opts \\ []) do
    enable_telemetry()

    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("EXECUTION DEBUG")
    IO.puts(String.duplicate("=", 60))

    # Use Serial executor for step-by-step
    merged_opts = Keyword.merge(opts, executor_and_opts: {Orchid.Executor.Serial, []})

    case Orchid.run(recipe, initial_params, merged_opts) do
      {:ok, results} ->
        IO.puts("\n" <> String.duplicate("=", 60))
        IO.puts("✅ EXECUTION SUCCEEDED")
        IO.puts(String.duplicate("=", 60))

        Enum.each(results, fn {key, param} ->
          IO.puts("  #{key}: #{inspect(param)}")
        end)

        {:ok, results}

      {:error, %Orchid.Error{
        reason: reason,
        step_id: step_id,
        context: ctx,
        kind: kind
      }} ->
        IO.puts("\n" <> String.duplicate("=", 60))
        IO.puts("❌ EXECUTION FAILED")
        IO.puts(String.duplicate("=", 60))

        IO.puts("\nError Details:")
        IO.puts("  Step: #{inspect(step_id)}")
        IO.puts("  Kind: #{kind}")
        IO.puts("  Reason: #{inspect(reason)}")

        IO.puts("\nExecution History:")

        Enum.each(ctx.history, fn {step, keys} ->
          {impl, _, _} = Orchid.Step.extract_schema(step)
          IO.puts("  ✓ #{impl} → #{inspect(MapSet.to_list(keys))}")
        end)

        IO.puts("\nPending Steps:")

        Enum.each(ctx.pending_steps, fn {step, idx} ->
          {impl, in_k, _} = Orchid.Step.extract_schema(step)
          IO.puts("  ⏳ [#{idx}] #{impl}")
          IO.puts("      Waiting for: #{inspect(in_k)}")
        end)

        IO.puts("\nAvailable Keys:")
        IO.puts("  #{inspect(MapSet.to_list(ctx.available_keys))}")

        {:error, reason}
    end
  end
end

# Usage:
# DebugExecution.run_with_debug(my_recipe, my_params)
