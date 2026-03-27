defmodule Orchid.RunnerHooks.TelemetryTest do
  use ExUnit.Case

  defmodule ReportingStep do
    use Orchid.Step

    def run(_in, opts) do
      report(opts, 50, "Halfway")
      {:ok, Orchid.Param.new(:out, :string, "Done")}
    end
  end

  defmodule ReportingCrash do
    use Orchid.Step

    def run(_, opts) do
      report(opts, 40)  # Noise without payload
      report(opts, 40, "Normal")

      raise "error"
    end
  end

  defmodule SpawnUnstableProcess do
    use Orchid.Step

    def run(_, _step_options) do
      throw("Blabla")

      {:ok, Orchid.Param.new(:out, :blank, [])}
    end
  end

  defmodule TestHandler do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end
  end

  setup do
    handler_id = "test-handler-#{inspect(self())}"

    on_exit(fn ->
      :telemetry.detach(handler_id)
    end)

    :ok =
      :telemetry.attach_many(
        handler_id,
        [
          [:orchid, :step, :start],
          [:orchid, :step, :done],
          [:orchid, :step, :progress],
          [:orchid, :step, :exception]
        ],
        &TestHandler.handle_event/4,
        self()
      )

    :telemetry.attach(
      "orchid-step-exception-logger",
      [:orchid, :step, :exception],
      &Orchid.Runner.Hooks.Telemetry.error_handler/4,
      %{}
    )

    :ok
  end

  test "emits telemetry events" do
    recipe = Orchid.Recipe.new([{ReportingStep, :in, :out}])
    initial = [Orchid.Param.new(:in, :string, "Hi")]
    Orchid.run(recipe, initial)

    assert_receive {:telemetry_event, [:orchid, :step, :start], _, %{impl: ReportingStep}}

    assert_receive {:telemetry_event, [:orchid, :step, :progress], %{progress: 50}, meta}
    assert meta.payload == "Halfway"

    assert_receive {:telemetry_event, [:orchid, :step, :done], %{duration: _}, _}

    recipe2 = Orchid.Recipe.new([{ReportingCrash, :in, :out}])

    {:error, _} = Orchid.run(recipe2, initial)

    assert_receive {:telemetry_event, [:orchid, :step, :exception], %{duration: _}, _}

    recipe3 = Orchid.Recipe.new([{SpawnUnstableProcess, :in, :out}])

    Orchid.run(recipe3, initial)

    assert_receive {:telemetry_event, [:orchid, :step, :exception], %{duration: _}, _}
  end

  defmodule TelemetryBlocker do
    @behaviour Orchid.Runner.Hook

    def call(ctx, next_fn) do
      next_fn.(%{
        ctx
        | step_opts: Keyword.reject(ctx.step_opts, fn {k, _} -> k == :__reporter_ctx__ end)
      })
    end
  end

  test "orchid can run well without telemetry" do
    # Only used to increase coverage.
    recipe = Orchid.Recipe.new([{ReportingStep, :in, :out}])
    initial = [Orchid.Param.new(:in, :string, "Hi")]
    Orchid.run(recipe, initial, global_hooks_stack: [TelemetryBlocker])
  end
end
