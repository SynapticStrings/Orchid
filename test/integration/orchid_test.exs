defmodule OrchidTest do
  use ExUnit.Case
  doctest Orchid

  alias Orchid.{Param, Recipe}
  alias Orchid.TestSteps.{Denoise, PitchFix, Mix}

  test "runs the vocal mixing pipeline successfully" do
    initial_params = [
      Param.new(:raw_vocal, :audio, ["V1", "V2"]),
      Param.new(:bgm, :audio, ["B1", "B2"])
    ]

    steps = [
      {Mix, [:tuned_vocal, :bgm], :final_track},
      {Denoise, :raw_vocal, :clean_vocal},
      {PitchFix, :clean_vocal, :tuned_vocal}
    ]

    recipe = Recipe.new(steps)

    assert {:ok, results} = Orchid.run(recipe, initial_params)

    final_param = results[:final_track]
    assert final_param.name == :final_track

    expected_payload = [
      "Mix[V1_denoised_tuned + B1]",
      "Mix[V2_denoised_tuned + B2]"
    ]

    assert Param.get_payload(final_param) == expected_payload
  end

  test "detects stuck execution (missing dependency)" do
    initial_params = [
      Param.new(:raw_vocal, :audio, ["V1"])
    ]

    steps = [
      {Mix, [:tuned_vocal, :bgm], :final_track},
      {Denoise, :raw_vocal, :clean_vocal},
      {PitchFix, :clean_vocal, :tuned_vocal}
    ]

    recipe = Recipe.new(steps)

    # return error as exceptation
    {:error, %Orchid.Error{reason: {:missing_inputs, missing_map}}} =
      Orchid.run(recipe, initial_params)

    assert Map.get(missing_map, 0) == [:bgm]
  end

  test "function step can also running" do
    step1 = fn _, _ -> {:ok, Param.new(:mid, :string) |> Param.set_payload("Mid")} end
    step2 = fn _, _ -> {:ok, Param.new(:fin, :string) |> Param.set_payload("Fin")} end
    recipe = Recipe.new([{step1, :in, :mid}, {step2, :mid, :fin}])

    {:ok, _res} = Orchid.run(recipe, [Param.new(:in, :string) |> Param.set_payload("In")])
  end
end
