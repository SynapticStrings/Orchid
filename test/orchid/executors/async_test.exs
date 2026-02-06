defmodule SleepStep do
  use Orchid.Step

  def run(param, opts) do
    Process.sleep(Keyword.get(opts, :sleep, 1000))

    {:ok, %Orchid.Param{name: param.name, payload: param.payload + 1}}
  end
end

defmodule Orchid.Executor.AsyncTest do
  use ExUnit.Case
  alias Orchid.Scheduler
  alias Orchid.{Executor.Async, Recipe, Param}
  alias Orchid.Step.NestedStep, as: Nested
  alias Orchid.TestSteps.{Denoise, PitchFix, Mix}

  test "executes independent steps concurrently" do
    steps1 = [
      {SleepStep, :a, :b},
      {SleepStep, :c, :d}
    ]

    recipe1 = Recipe.new(steps1)
    initial1 = [%Param{name: :a, payload: 1}, %Param{name: :c, payload: 2}]
    start1 = System.monotonic_time()
    {:ok, ctx1} = Scheduler.build(recipe1, initial1, Orchid.WorkflowCtx.new())
    {:ok, _} = Async.execute(ctx1, concurrency: 2)
    duration1 = System.monotonic_time() - start1

    steps2 = [
      {SleepStep, :input, :mid},
      {SleepStep, :mid, :output}
    ]

    recipe2 = Recipe.new(steps2)
    initial2 = [%Param{name: :input, payload: 1}]
    start2 = System.monotonic_time()
    {:ok, ctx2} = Scheduler.build(recipe2, initial2, Orchid.WorkflowCtx.new())
    {:ok, _res} = Async.execute(ctx2, concurrency: 2)
    duration2 = System.monotonic_time() - start2
    assert duration2 >= 1.5 * duration1
  end

  test "propagates errors" do
    steps = [{ErrorStep, :input, :output}]
    recipe = Recipe.new(steps)
    initial = [%Param{name: :input, payload: 1}]
    {:ok, ctx} = Scheduler.build(recipe, initial, Orchid.WorkflowCtx.new())
    {:error, %Orchid.Error{}} = Async.execute(ctx, [])
  end

  test "a complex test" do
    inner_recipe =
      Recipe.new([
        {Denoise, :raw, :clean},
        {PitchFix, :clean, :tuned},
        {Mix, [:tuned, :bgm], :mix}
      ])

    main_recipe =
      [
        {Nested, [:raw1, :bgm], :mix1,
         recipe: inner_recipe, input_map: %{raw1: :raw, bgm: :bgm}, output_map: %{mix: :mix1}},
        {Nested, [:raw2, :bgm], :mix2,
         recipe: inner_recipe, input_map: %{raw2: :raw, bgm: :bgm}, output_map: %{mix: :mix2}},
        {fn param, _ ->
           res = param |> Param.get_payload() |> hd() |> String.to_integer()
           {:ok, Orchid.Param.new(:any, :any, res)}
         end, :raw1, :mid1},
         {ErrorStep, :raw1, :mid2},
        {SleepStep, :mid1, :void, [sleep: 10000]}
      ]
      |> Recipe.new()

    initial = [
      %Param{name: :raw1, payload: ["1"]},
      %Param{name: :raw2, payload: ["2"]},
      %Param{name: :bgm, payload: ["Beat"]}
    ]

    {:ok, ctx} =
      Scheduler.build(
        main_recipe,
        initial,
        Orchid.WorkflowCtx.new()
      )

    {:error, %Orchid.Error{}} = Async.execute(ctx, [])
  end
end
