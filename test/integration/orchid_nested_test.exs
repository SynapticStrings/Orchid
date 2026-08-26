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
      [
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
      ]
      |> Recipe.new()

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

  test "nested recipe without explicit io map" do
    alias Orchid.Step.NestedStep, as: Nested

    alias Orchid.{Param, Recipe}
    alias Orchid.TestSteps.{Denoise, PitchFix, Mix}

    child_recipe =
      Recipe.new([
        {Denoise, :child_raw, :child_clean},
        {PitchFix, :child_clean, :child_tuned}
      ])

    main_recipe1 =
      Recipe.new([
        {
          Nested,
          :child_raw,
          :child_tuned,
          [recipe: child_recipe]
        },
        {Mix, [:child_tuned, :bgm], :final_mix}
      ])

    main_recipe2 =
      Recipe.new([
        {
          Nested,
          :child_raw,
          [:child_tuned],
          [recipe: child_recipe]
        },
        {Mix, [:child_tuned, :bgm], :final_mix}
      ])

    initial_params = [
      Param.new(:child_raw, :audio, ["Vocal1"]),
      Param.new(:bgm, :audio, ["Beat1"])
    ]

    assert {:ok, results} = Orchid.run(main_recipe1, initial_params)
    assert {:ok, _results} = Orchid.run(main_recipe2, initial_params)

    final = results[:final_mix]
    payload = Param.get_payload(final)

    expected = ["Mix[Vocal1_denoised_tuned + Beat1]"]
    assert payload == expected
  end

  test "Run with error" do
    alias Orchid.Step.NestedStep, as: Nested

    alias Orchid.{Param, Recipe}
    alias Orchid.TestSteps.{Denoise, PitchFix, Mix}

    child_recipe =
      Recipe.new([
        {Denoise, :child_raw, :child_clean},
        {PitchFix, :child_clean, :child_tuned_pre},
        {fn _, _ ->
           raise "Err"
           {:error, :void}
         end, :child_tuned_pre, :child_tuned}
      ])

    main_recipe =
      [
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
      ]
      |> Recipe.new()

    initial_params = [
      Param.new(:parent_raw, :audio, ["Vocal1"]),
      Param.new(:bgm, :audio, ["Beat1"])
    ]

    assert {:error, %Orchid.Error{}} = Orchid.run(main_recipe, initial_params)

    child_recipe2 =
      Recipe.new([
        {Denoise, :child_raw, :child_clean},
        {PitchFix, :child_clean, :child_tuned_pre}
      ])

    main_recipe2 =
      [
        {
          Nested,
          :parent_raw,
          :parent_result,
          [
            recipe: child_recipe2,
            input_map: %{parent_raw: :child_raw},
            output_map: %{child_untuned: :parent_result}
          ]
        },
        {Mix, [:parent_result, :bgm], :final_mix}
      ]
      |> Recipe.new()

    assert {:error, %Orchid.Error{}} = Orchid.run(main_recipe2, initial_params)

    assert %Orchid.Operon.Response{} =
             Orchid.run(main_recipe2, initial_params, return_response: true)
  end
end
