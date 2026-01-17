defmodule Orchid.Integration.SpecialTest do
  alias Orchid.{WorkflowCtx, Param}
  # for Special
  use ExUnit.Case

  defmodule SpecialStep do
    use Orchid.Step

    def run(_input, _opts) do
      {:special, nil}
    end
  end

  defmodule TestHandler do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end
  end

  describe "runner can handle special" do
    setup do
      :telemetry.attach_many(
        "test-handler-for-special",
        [
          [:orchid, :step, :start],
          [:orchid, :step, :special]
        ],
        &TestHandler.handle_event/4,
        self()
      )

      :ok
    end

    # Orchid.Runner.Hooks.Core => do nothing

    # Orchid.Runner.Hooks.Telemetry =>
    # execute
    test "telemetry can send message when receive special" do
      {:special, _} =
        Orchid.Runner.run(
          {SpecialStep, [:foo, :bar], {:a, :b, :c}, []},
          %{foo: Param.new(:foo, :void, nil), bar: Param.new(:bar, :void, nil)},
          [],
          WorkflowCtx.new()
        )

      assert_receive {:telemetry_event, [:orchid, :step, :start], _, _meta}
      assert_receive {:telemetry_event, [:orchid, :step, :special], _, _meta}

      :telemetry.detach("test-handler-for-special")
    end
  end

  defp load_orchid_opts(_context) do
    recipe = Orchid.Recipe.new([{SpecialStep, [:foo, :bar], {:a, :b, :c}}])
    foo = Param.new(:foo, :void, nil)
    bar = Param.new(:bar, :void, nil)

    %{
      opts: [
        recipe,
        %{foo: foo, bar: bar}
      ]
    }
  end

  describe "core executor can't handle special" do
    setup [:load_orchid_opts]

    test "return error when serial", %{opts: opts} do
      assert {:error, %Orchid.Error{reason: {:core_executor_not_support_special, nil}}} =
               apply(Orchid, :run, opts ++ [[executor_and_opts: {Orchid.Executor.Serial, []}]])
    end

    test "return error when async", %{opts: opts} do
      assert {:error, %Orchid.Error{reason: {:core_executor_not_support_special, nil}}} =
               apply(Orchid, :run, opts ++ [[executor_and_opts: {Orchid.Executor.Async, []}]])
    end
  end
end
