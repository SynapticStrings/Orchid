defmodule Orchid.NestedTest do
  use ExUnit.Case
  alias Orchid.Step.NestedStep, as: Nested

  alias Orchid.{Param, Recipe}
  alias Orchid.TestSteps.{Denoise, PitchFix, Mix}

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
    assert {:ok, results} = Orchid.run(main_recipe, initial_params)

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
