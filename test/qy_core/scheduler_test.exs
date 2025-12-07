defmodule DummyStep do
  use QyCore.Step
  def run(inputs, _opts), do: {:ok, List.wrap(inputs)}
end

defmodule ExtraHook do
  @behaviour QyCore.Runner.Hook
  def call(ctx, next), do: next.(ctx)
end

defmodule QyCore.SchedulerTest do
  use ExUnit.Case
  alias QyCore.{Scheduler, Recipe, Param}

  describe "build/2" do
    test "initializes context with valid recipe" do
      steps = [{DummyStep, :input, :output}]
      recipe = Recipe.new(steps)
      initial_params = [%Param{name: :input, type: :test, payload: "data"}]
      {:ok, ctx} = Scheduler.build(recipe, initial_params)
      assert length(ctx.pending_steps) == 1
      assert MapSet.member?(ctx.available_keys, :input)
      assert ctx.params[:input].payload == "data"
    end

    test "detects cycle detect" do
      steps = [{DummyStep, :a, :b}, {DummyStep, :b, :a}]
      recipe = Recipe.new(steps, [%Param{name: :a}])
      {:error, {:cyclic, [{DummyStep, _, _}, {DummyStep, _, _}]}} =
        Scheduler.build(recipe, [])
    end
  end

  describe "next_ready_steps/1" do
    test "returns ready steps in topological order" do
      steps = [
        {DummyStep, :a, :b},
        {DummyStep, :b, :c},
        {DummyStep, [:a, :c], :d}
      ]

      recipe = Recipe.new(steps)
      initial = [%Param{name: :a, payload: 1}]
      {:ok, ctx} = Scheduler.build(recipe, initial)
      assert [{_, 0}] = Scheduler.next_ready_steps(ctx)
    end
  end

  describe "merge_result/3" do
    test "merges output and updates context" do
      steps = [{DummyStep, :input, :output}]
      recipe = Recipe.new(steps)
      initial = [%Param{name: :input, payload: "in"}]
      {:ok, ctx} = Scheduler.build(recipe, initial)
      output = %Param{name: :output, payload: "out"}
      new_ctx = Scheduler.merge_result(ctx, 0, output)
      assert Scheduler.done?(new_ctx)
      assert new_ctx.params[:output].payload == "out"
    end
  end

  describe "update_pending_steps_options/3" do
    test "updates options for matching steps" do
      steps = [{DummyStep, :in, :out, extra_hooks_stack: []}]
      recipe = Recipe.new(steps)
      {:ok, ctx} = Scheduler.build(recipe, [%Param{name: :in, payload: nil}])
      selector = fn {impl, _, _, _} -> impl == DummyStep end

      new_ctx =
        Scheduler.update_pending_steps_options(ctx, selector, extra_hooks_stack: [ExtraHook])

      {_, _, _, opts} = hd(new_ctx.pending_steps) |> elem(0)
      assert opts[:extra_hooks_stack] == [ExtraHook]
    end
  end

  describe "done?/1 and get_results/1" do
    test "checks completion and retrieves results" do
      recipe = Recipe.new([])
      {:ok, ctx} = Scheduler.build(recipe, [])
      assert Scheduler.done?(ctx)
      assert Scheduler.get_results(ctx) == %{}
    end
  end
end
