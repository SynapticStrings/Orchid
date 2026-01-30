#!/usr/bin/env elixir
# Profile step execution times and bottlenecks

defmodule StepProfiler do
  require Logger

  def profile_recipe(recipe, initial_params) do
    step_times = []
    step_times_ref = :ets.new(:step_times, [:bag])

    # Attach profiler
    :telemetry.attach("step-profiler", [:orchid, :step, :done],
      fn event, measurements, meta ->
        duration_us = measurements.duration
        :ets.insert(step_times_ref, {meta.impl, duration_us})
      end, nil)

    IO.puts("Profiling recipe execution...\n")

    case Orchid.run(recipe, initial_params,
      executor_and_opts: {Orchid.Executor.Async, []}
    ) do
      {:ok, _results} ->
        print_profile(step_times_ref)

      {:error, error} ->
        IO.puts("Execution failed: #{inspect(error)}")
    end

    :telemetry.detach("step-profiler")
    :ets.delete(step_times_ref)
  end

  defp print_profile(ref) do
    IO.puts(String.duplicate("=", 60))
    IO.puts("STEP PROFILING RESULTS")
    IO.puts(String.duplicate("=", 60) <> "\n")

    results =
      :ets.tab2list(ref)
      |> Enum.group_by(fn {impl, _} -> impl end)
      |> Enum.map(fn {impl, samples} ->
        times = Enum.map(samples, fn {_, us} -> us end)

        {
          impl,
          Enum.sum(times),
          Enum.count(times),
          Enum.sum(times) / Enum.count(times)
        }
      end)
      |> Enum.sort_by(fn {_, total, _, _} -> -total end)

    total_time = Enum.reduce(results, 0, fn {_, total, _, _}, acc -> acc + total end)

    Enum.each(results, fn {impl, total_us, count, avg_us} ->
      pct = round(total_us / total_time * 100)
      total_ms = total_us / 1000
      avg_ms = avg_us / 1000

      IO.puts("#{impl}")
      IO.puts(
        "  Total: #{total_ms}ms (#{pct}%)" <>
          " | Count: #{count} | Avg: #{avg_ms}ms\n"
      )
    end)

    IO.puts(String.duplicate("=", 60))
    IO.puts("Total: #{total_time / 1_000_000}ms\n")
  end
end

# Usage:
# elixir step_profiler.exs
