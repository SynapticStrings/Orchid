
defmodule QyCore.TelemetryTest do
  use ExUnit.Case

  defmodule ReportingStep do
    use QyCore.Step

    def run(_in, opts) do
      report(opts, 50, "Halfway")
      {:ok, Param.new(:out, :string, "Done")}
    end
  end

  # 定义一个 Handler，把事件转发给 Test 进程
  defmodule TestHandler do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end
  end

  test "emits telemetry events" do
    # 1. 注册监听器
    :telemetry.attach_many(
      "test-handler",
      [
        [:qy_core, :step, :start],
        [:qy_core, :step, :stop],
        [:qy_core, :step, :progress]
      ],
      &TestHandler.handle_event/4,
      # config: 传给 handle_event 的第4个参数
      self()
    )

    # 2. 运行
    recipe = Recipe.new([{ReportingStep, :in, :out}])
    initial = [Param.new(:in, :string, "Hi")]
    QyCore.run(recipe, initial)

    # 3. 验证收到的消息
    assert_receive {:telemetry_event, [:qy_core, :step, :start], _, %{impl: ReportingStep}}

    assert_receive {:telemetry_event, [:qy_core, :step, :progress], %{progress: 50}, meta}
    assert meta.payload == "Halfway"

    assert_receive {:telemetry_event, [:qy_core, :step, :stop], %{duration: _}, _}

    # 清理
    :telemetry.detach("test-handler")
  end
end
