defmodule SuccessStep do
  use Orchid.Step
  def run(param, _opts), do: {:ok, %Orchid.Param{name: param.name, payload: param.payload + 1}}
end

defmodule ErrorStep do
  use Orchid.Step
  def run(_, _opts), do: {:error, :failed}
end

defmodule Orchid.Executor.SerialTest do
  use ExUnit.Case
  alias Orchid.Scheduler
  alias Orchid.{Executor.Serial, Recipe, Param}

  test "executes steps serially" do
    steps = [
      {SuccessStep, :input, :mid},
      {SuccessStep, :mid, :output}
    ]

    recipe = Recipe.new(steps)
    initial = [%Param{name: :input, payload: 1}]
    {:ok, ctx} = Scheduler.build(recipe, initial, Orchid.WorkflowCtx.new())
    {:ok, results} = Serial.execute(ctx, [])
    assert (fn {_, v} -> v end).(Enum.find(results, fn {k, _} -> k == :output end)).payload == 3
  end

  test "handles errors" do
    steps = [{ErrorStep, :input, :output}]
    recipe = Recipe.new(steps)
    initial = [%Param{name: :input, payload: 1}]
    {:ok, ctx} = Scheduler.build(recipe, initial, Orchid.WorkflowCtx.new())
    {:error, %Orchid.Error{reason: :failed}} = Serial.execute(ctx, [])
  end

  # TODO:
  test "can return stuck" do
    # Here I am.
    broken_ctx = %Orchid.Scheduler.Context{
      recipe: %Orchid.Recipe{},
      pending_steps: [{{SuccessStep, :input, :mid, []}, 0}],
      available_keys: MapSet.new([]),
      running_steps: MapSet.new(),
      workflow_ctx: Orchid.WorkflowCtx.new(),
      params: %{}
    }

    {:error, %Orchid.Error{reason: :stuck}} = Serial.execute(broken_ctx, [])
  end
end
