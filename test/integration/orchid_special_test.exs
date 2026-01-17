defmodule Orchid.Integration.SpecialTest do
  alias Orchid.{WorkflowCtx, Param}
  # for Special
  use ExUnit.Case

  defmodule SpecialStep do
    use Orchid.Step

    def run(_input, opts) do
      report(opts, :Aha!)

      {:special, nil}
    end
  end

  defmodule TestHandler do
    def handle_event(event, measurements, metadata, test_pid) do
      send(test_pid, {:telemetry_event, event, measurements, metadata})
    end
  end

  setup do
    :telemetry.attach_many(
      "test-handler-for-special",
      [
        [:orchid, :step, :start],
        [:orchid, :step, :done],
        [:orchid, :step, :progress],
        [:orchid, :step, :special]
      ],
      &TestHandler.handle_event/4,
      self()
    )

    # build runner context
    # {:ok,
    #  %Orchid.Runner.Context{
    #    step_implementation: SpecialStep,
    #    in_keys: [:foo, :bar],
    #    out_keys: {:a, :b, :c},
    #    inputs: %{foo: Param.new(:foo, :void, nil), bar: Param.new(:bar, :void, nil)},
    #    recipe_opts: [],
    #    telemetry_meta: %{impl: SpecialStep, in_keys: [:foo, :bar], out_keys: {:a, :b, :c}},
    #    workflow_ctx: WorkflowCtx.new(),
    #    assigns: %{}
    #  }}

    :ok
  end

  describe "runner can handle special" do
    # Orchid.Runner.Hooks.Core => do nothing

    # Orchid.Runner.Hooks.Telemetry =>
    # execute
    test "telemetry can send message when receive special" do
      assert {:special, _} =
               Orchid.Runner.run(
                 {SpecialStep, [:foo, :bar], {:a, :b, :c}, []},
                 %{foo: Param.new(:foo, :void, nil), bar: Param.new(:bar, :void, nil)},
                 [],
                 WorkflowCtx.new()
               )

      assert_receive {:telemetry_event, [:orchid, :step, :progress], %{progress: :Aha!}, meta}
      assert meta.payload == nil

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
