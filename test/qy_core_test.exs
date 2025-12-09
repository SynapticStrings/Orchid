defmodule QySynth.Steps.Denoise do
  use QyCore.Step
  alias QyCore.Param

  def run(input_param, _opts) do
    # 模拟降噪
    raw_data = Param.get_payload(input_param)
    processed = Enum.map(raw_data, &(&1 <> "_denoised"))
    {:ok, Param.new(:clean_vocal, :audio) |> Param.set_payload(processed)}
  end
end

defmodule QySynth.Steps.PitchFix do
  use QyCore.Step
  alias QyCore.Param

  def run(input_param, _opts) do
    # 模拟修音
    data = Param.get_payload(input_param)
    processed = Enum.map(data, &(&1 <> "_tuned"))
    {:ok, Param.new(:tuned_vocal, :audio) |> Param.set_payload(processed)}
  end
end

defmodule QySynth.Steps.Mix do
  use QyCore.Step
  alias QyCore.Param

  # 注意：这里接收两个参数的 List
  def run([vocal_param, bgm_param], _opts) do
    vocal = Param.get_payload(vocal_param)
    bgm = Param.get_payload(bgm_param)

    mixed = Enum.zip_with(vocal, bgm, fn v, b -> "Mix[#{v} + #{b}]" end)
    {:ok, Param.new(:final_track, :audio) |> Param.set_payload(mixed)}
  end
end

alias QyCore.{Param, Recipe}
alias QySynth.Steps.{Denoise, PitchFix, Mix}

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
    {:error, {:missing_inputs, missing_map}} = QyCore.run(recipe, initial_params)
    assert Map.get(missing_map, 0) == [:bgm]
  end

  test "function step can also running" do
    step1 = fn _, _ -> {:ok, Param.new(:mid, :string) |> Param.set_payload("Mid")} end
    step2 = fn _, _ -> {:ok, Param.new(:fin, :string) |> Param.set_payload("Fin")} end
    recipe = Recipe.new([{step1, :in, :mid}, {step2, :mid, :fin}])

    {:ok, _res} = QyCore.run(recipe, [Param.new(:in, :string) |> Param.set_payload("In")])
  end
end

defmodule QyCore.NestedTest do
  use ExUnit.Case
  alias QyCore.Step.NestedStep, as: Nested

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
