
defmodule QyCore.TelemetryTest do
  use ExUnit.Case

  defmodule ReportingStep do
    use QyCore.Step

    def run(_in, opts) do
      report(opts, 50, "Halfway")
      {:ok, QyCore.Param.new(:out, :string, "Done")}
    end
  end

  defmodule ReportingCrash do
    use QyCore.Step

    def run(_, opts) do
      report(opts, 40, "Normal")

      raise "error"
    end
  end

  defmodule SpawnUnstableProcess do
    use QyCore.Step

    def run(_, _step_options) do
      throw("Blabla")

      {:ok, QyCore.Param.new(:out, :blank, [])}
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
        [:qy_core, :step, :start],
        [:qy_core, :step, :stop],
        [:qy_core, :step, :progress],
        [:qy_core, :step, :exception]
      ],
      &TestHandler.handle_event/4,
      # config: 传给 handle_event 的第4个参数
      self()
    )

    :ok
  end

  test "emits telemetry events" do
    recipe = QyCore.Recipe.new([{ReportingStep, :in, :out}])
    initial = [QyCore.Param.new(:in, :string, "Hi")]
    QyCore.run(recipe, initial)

    assert_receive {:telemetry_event, [:qy_core, :step, :start], _, %{impl: ReportingStep}}

    assert_receive {:telemetry_event, [:qy_core, :step, :progress], %{progress: 50}, meta}
    assert meta.payload == "Halfway"

    assert_receive {:telemetry_event, [:qy_core, :step, :stop], %{duration: _}, _}

    recipe2 = QyCore.Recipe.new([{ReportingCrash, :in, :out}])

    {:error, _} = QyCore.run(recipe2, initial)

    assert_receive {:telemetry_event, [:qy_core, :step, :exception], %{duration: _}, _}

    recipe3 = QyCore.Recipe.new([{SpawnUnstableProcess, :in, :out}])

    QyCore.run(recipe3, initial)

    assert_receive {:telemetry_event, [:qy_core, :step, :exception], %{duration: _}, _}

    :telemetry.detach("test-handler")
  end
end
