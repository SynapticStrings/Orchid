defmodule QySynth.Steps.Denoise do
  use QyCore.Recipe.Step
  alias QyCore.Param

  def run(input_param, _opts) do
    # 模拟降噪
    raw_data = Param.get_payload(input_param)
    processed = Enum.map(raw_data, &(&1 <> "_denoised"))
    {:ok, Param.new(:clean_vocal, :audio, processed)}
  end
end

defmodule QySynth.Steps.PitchFix do
  use QyCore.Recipe.Step
  alias QyCore.Param

  def run(input_param, _opts) do
    # 模拟修音
    data = Param.get_payload(input_param)
    processed = Enum.map(data, &(&1 <> "_tuned"))
    {:ok, Param.new(:tuned_vocal, :audio, processed)}
  end
end

defmodule QySynth.Steps.Mix do
  use QyCore.Recipe.Step
  alias QyCore.Param

  # 注意：这里接收两个参数的 List
  def run([vocal_param, bgm_param], _opts) do
    vocal = Param.get_payload(vocal_param)
    bgm = Param.get_payload(bgm_param)

    mixed = Enum.zip_with(vocal, bgm, fn v, b -> "Mix[#{v} + #{b}]" end)
    {:ok, Param.new(:final_track, :audio, mixed)}
  end
end

alias QyCore.{Param, Recipe}
alias QySynth.Steps.{Denoise, PitchFix, Mix}

vocal_chain_steps = [
  {Denoise, :raw_audio, :clean_audio},
  {PitchFix, :clean_audio, :tuned_audio}
]

_vocal_chain_recipe = Recipe.new(vocal_chain_steps, name: :vocal_chain)

main_steps = [
  # --- 嵌套步骤 ---
  {
    Recipe.NestedStep,
    :microphone_input,
    :ready_vocal,
    # Options
    [
      recipe: Recipe.new(vocal_chain_steps, name: :vocal_chain),
      # 映射: 主流程名 => 子流程名
      input_map: %{microphone_input: :raw_audio},
      # 映射: 子流程名 => 主流程名
      output_map: %{tuned_audio: :ready_vocal}
    ]
  },
  {Mix, [:ready_vocal, :bgm], :final_track}
]

main_recipe = Recipe.new(main_steps, name: :main_mix)

defmodule QyCoreTest do
  use ExUnit.Case
  doctest QyCore

  test "runs the vocal mixing pipeline successfully" do
    # 1. 准备初始素材 (Payload 是 List)
    initial_params = [
      Param.new(:raw_vocal, :audio, ["V1", "V2"]),
      Param.new(:bgm, :audio, ["B1", "B2"])
    ]

    # 2. 定义 Recipe (乱序，测试调度能力)
    steps = [
      # Step 3: Mix (需要 Tuned + BGM)
      {Mix, [:tuned_vocal, :bgm], :final_track},

      # Step 1: Denoise (需要 Raw)
      {Denoise, :raw_vocal, :clean_vocal},

      # Step 2: PitchFix (需要 Clean)
      {PitchFix, :clean_vocal, :tuned_vocal}
    ]

    recipe = Recipe.new(steps)

    # 3. 执行
    assert {:ok, results} = QyCore.run(recipe, initial_params)

    # 4. 验证结果
    final_param = results[:final_track]
    assert final_param.name == :final_track

    # 验证数据流转逻辑是否正确：V1 -> V1_denoised -> V1_denoised_tuned -> Mix[...]
    expected_payload = [
      "Mix[V1_denoised_tuned + B1]",
      "Mix[V2_denoised_tuned + B2]"
    ]

    assert Param.get_payload(final_param) == expected_payload
  end

  test "detects stuck execution (missing dependency)" do
    initial_params = [
      Param.new(:raw_vocal, :audio, ["V1"])
      # 无 BGM
    ]

    steps = [
      # 这一步永远无法满足
      {Mix, [:tuned_vocal, :bgm], :final_track},
      {Denoise, :raw_vocal, :clean_vocal},
      {PitchFix, :clean_vocal, :tuned_vocal}
    ]

    recipe = Recipe.new(steps)

    # 预期报错
    {:error, {:missing_inputs, idx, missing_values}} = QyCore.run(recipe, initial_params)
    assert idx == 0
    assert :bgm in missing_values
  end
end

defmodule QyCore.NestedTest do
  use ExUnit.Case
  alias QyCore.Recipe.NestedStep, as: Nested

  test "executes nested recipe correctly with param mapping" do
    # 1. 准备子 Recipe
    child_recipe =
      Recipe.new([
        {Denoise, :child_raw, :child_clean},
        {PitchFix, :child_clean, :child_tuned}
      ])

    # 2. 准备主 Recipe
    main_recipe =
      Recipe.new([
        {
          Nested,
          # 主流程提供的输入
          :parent_raw,
          # 主流程期望的输出
          :parent_result,
          [
            recipe: child_recipe,
            # 桥接: parent -> child
            input_map: %{parent_raw: :child_raw},
            # 桥接: child -> parent
            output_map: %{child_tuned: :parent_result}
          ]
        },
        # 验证输出是否可用
        {Mix, [:parent_result, :bgm], :final_mix}
      ])

    # 3. 初始数据
    initial_params = [
      Param.new(:parent_raw, :audio, ["Vocal1"]),
      Param.new(:bgm, :audio, ["Beat1"])
    ]

    # 4. 运行
    assert {:ok, results} = QyCore.run(main_recipe, initial_params)

    # 5. 验证
    final = results[:final_mix]
    payload = Param.get_payload(final)

    # 逻辑链:
    # Vocal1 (parent_raw)
    # -> map to :child_raw
    # -> Denoise -> Vocal1_denoised
    # -> PitchFix -> Vocal1_denoised_tuned (child_tuned)
    # -> map to :parent_result
    # -> Mix with Beat1

    expected = ["Mix[Vocal1_denoised_tuned + Beat1]"]
    assert payload == expected
  end
end

defmodule QyCore.WalkTest do
  use ExUnit.Case
  alias QyCore.Recipe.NestedStep
  alias QySynth.Steps.Mix

  test "assign_options penetrates into nested recipes" do
    # 1. 构建最内层 Recipe (Sub-Sub-Recipe)
    inner_recipe =
      Recipe.new([
        # 这里的 opts 此时是空的
        {Mix, :in, :out}
      ])

    # 2. 构建中间层 Recipe (包含 NestedStep)
    middle_steps = [
      {NestedStep, :a, :b, [recipe: inner_recipe]}
    ]

    middle_recipe = Recipe.new(middle_steps)

    # 3. 构建最外层 Recipe
    outer_steps = [
      {NestedStep, :x, :y, [recipe: middle_recipe]}
    ]

    outer_recipe = Recipe.new(outer_steps)

    # --- 行动：在最顶层注入配置 ---
    # 我们希望所有的 Mix 步骤（不管藏多深）都带上 sample_rate: 48000
    updated_recipe = Recipe.assign_options(outer_recipe, Mix, sample_rate: 48000)

    # --- 验证 ---
    # 这一步比较繁琐，因为要手动解包，但逻辑上就是剥洋葱

    # 第 1 层剥开
    # 外层 NestedStep
    {_, _, _, opts1} = hd(updated_recipe.steps)
    middle = opts1[:recipe]

    # 第 2 层剥开
    # 中间层 NestedStep
    {_, _, _, opts2} = hd(middle.steps)
    inner = opts2[:recipe]

    # 第 3 层：终于见到了 Mix
    {impl, _, _, final_opts} = hd(inner.steps)

    assert impl == Mix
    assert final_opts[:sample_rate] == 48000
  end
end

defmodule QyCore.TelemetryTest do
  use ExUnit.Case

  defmodule ReportingStep do
    use QyCore.Recipe.Step

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
