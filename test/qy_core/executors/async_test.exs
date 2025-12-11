defmodule SleepStep do
  use QyCore.Step

  def run(param, _opts) do
    Process.sleep(1000)
    {:ok, %QyCore.Param{name: param.name, payload: param.payload + 1}}
  end
end

defmodule QyCore.Executor.AsyncTest do
  use ExUnit.Case
  alias QyCore.Scheduler
  alias QyCore.{Executor.Async, Recipe, Param}

  test "executes independent steps concurrently" do
    steps1 = [
      {SleepStep, :a, :b},
      {SleepStep, :c, :d}
    ]

    recipe1 = Recipe.new(steps1)
    initial1 = [%Param{name: :a, payload: 1}, %Param{name: :c, payload: 2}]
    start1 = System.monotonic_time()
    {:ok, ctx1} = Scheduler.build(recipe1, initial1)
    {:ok, _} = Async.execute(ctx1, concurrency: 2)
    duration1 = System.monotonic_time() - start1

    steps2 = [
      {SleepStep, :input, :mid},
      {SleepStep, :mid, :output}
    ]

    recipe2 = Recipe.new(steps2)
    initial2 = [%Param{name: :input, payload: 1}]
    start2 = System.monotonic_time()
    {:ok, ctx2} = Scheduler.build(recipe2, initial2)
    {:ok, _res} = Async.execute(ctx2, concurrency: 2)
    duration2 = System.monotonic_time() - start2
    assert duration2 >= 1.5 * duration1
  end

  test "propagates errors" do
    steps = [{ErrorStep, :input, :output}]
    recipe = Recipe.new(steps)
    initial = [%Param{name: :input, payload: 1}]
    {:ok, ctx} = Scheduler.build(recipe, initial)
    {:error, {:step_failed, 0, :failed}} = Async.execute(ctx, [])
  end
end
