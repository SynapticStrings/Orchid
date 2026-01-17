defmodule Orchid.ErrorTest do
  use ExUnit.Case

  test "exception/1 callback is generated" do
    err = Orchid.Error.exception(reason: :test, kind: :logic)
    assert err.reason == :test
    assert err.kind == :logic
  end

  test "message/1 with specific step" do
    # Created a Mock Step
    step = {& &1, :foo, :bar}

    # Orchid Core not explicit raise %Orchid.Error{}
    # this is only used for test
    raiser_when_has_step = fn ->
      raise %Orchid.Error{
        reason: :increase_coverage,
        step_id: step |> Orchid.Step.ID.finger_print(),
        kind: :logic
      }
    end

    assert_raise Orchid.Error,
                 ~r/^Orchid execution failed at step {.*} \(logic\): :increase_coverage$/,
                 raiser_when_has_step

    raiser_when_without_step = fn ->
      raise %Orchid.Error{
        reason: :increase_coverage,
        kind: :logic
      }
    end

    assert_raise Orchid.Error,
                 ~r/^Orchid execution failed during running \(logic\): :increase_coverage$/,
                 raiser_when_without_step
  end
end
