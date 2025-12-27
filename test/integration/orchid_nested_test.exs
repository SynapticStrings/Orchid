defmodule Orchid.NestedTest do
  use ExUnit.Case
  alias Orchid.Step.NestedStep, as: Nested

  alias Orchid.{Param, Recipe}
  alias Orchid.TestSteps.{Denoise, PitchFix, Mix}

  test "executes nested recipe correctly with param mapping" do
    child_recipe =
      Recipe.new([
        {Denoise, :child_raw, :child_clean},
        {PitchFix, :child_clean, :child_tuned}
      ])

    main_recipe =
      Recipe.new([
        {
          Nested,
          :parent_raw,
          :parent_result,
          [
            recipe: child_recipe,
            input_map: %{parent_raw: :child_raw},
            output_map: %{child_tuned: :parent_result}
          ]
        },
        {Mix, [:parent_result, :bgm], :final_mix}
      ])

    initial_params = [
      Param.new(:parent_raw, :audio, ["Vocal1"]),
      Param.new(:bgm, :audio, ["Beat1"])
    ]

    assert {:ok, results} = Orchid.run(main_recipe, initial_params)

    final = results[:final_mix]
    payload = Param.get_payload(final)

    # Dataflow:
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
