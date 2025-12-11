defmodule Orchid.TelemetryTest do
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

  # 定义一个 Handler，把事件转发给 Test 进程
  defmodule TestHandler do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end
  end

  setup do
    :telemetry.attach_many(
      "test-handler",
      [
        [:orchid, :step, :start],
        [:orchid, :step, :stop],
        [:orchid, :step, :progress],
        [:orchid, :step, :exception]
      ],
      &TestHandler.handle_event/4,
      # config: 传给 handle_event 的第4个参数
      self()
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

    assert_receive {:telemetry_event, [:orchid, :step, :stop], %{duration: _}, _}

    recipe2 = Orchid.Recipe.new([{ReportingCrash, :in, :out}])

    {:error, _} = Orchid.run(recipe2, initial)

    assert_receive {:telemetry_event, [:orchid, :step, :exception], %{duration: _}, _}

    recipe3 = Orchid.Recipe.new([{SpawnUnstableProcess, :in, :out}])

    Orchid.run(recipe3, initial)

    assert_receive {:telemetry_event, [:orchid, :step, :exception], %{duration: _}, _}

    :telemetry.detach("test-handler")
  end
end
