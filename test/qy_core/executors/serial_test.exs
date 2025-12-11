defmodule SuccessStep do
  use QyCore.Step
  def run(param, _opts), do: {:ok, %QyCore.Param{name: param.name, payload: param.payload + 1}}
end

defmodule ErrorStep do
  use QyCore.Step
  def run(_, _opts), do: {:error, :failed}
end

defmodule QyCore.Executor.SerialTest do
  use ExUnit.Case
  alias QyCore.Scheduler
  alias QyCore.{Executor.Serial, Recipe, Param}

  test "executes steps serially" do
    steps = [
      {SuccessStep, :input, :mid},
      {SuccessStep, :mid, :output}
    ]

    recipe = Recipe.new(steps)
    initial = [%Param{name: :input, payload: 1}]
    {:ok, ctx} = Scheduler.build(recipe, initial)
    {:ok, results} = Serial.execute(ctx, [])
    assert (fn {_, v} -> v end).(Enum.find(results, fn {k, _} -> k == :output end)).payload == 3
  end

  test "handles errors" do
    steps = [{ErrorStep, :input, :output}]
    recipe = Recipe.new(steps)
    initial = [%Param{name: :input, payload: 1}]
    {:ok, ctx} = Scheduler.build(recipe, initial)
    {:error, :failed} = Serial.execute(ctx, [])
  end

  # test "handles missing" do
  #   steps = [{SuccessStep, :missing, :output}]
  #   recipe = Recipe.new(steps)
  #   {:error, {:missing_inputs, missing_map}} = Serial.execute(recipe, [])

  #   assert missing_map[0] == [:missing]
  # end
end
