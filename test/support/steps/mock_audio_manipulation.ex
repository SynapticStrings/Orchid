defmodule Orchid.TestSteps.Denoise do
  use Orchid.Step
  alias Orchid.Param

  def validate_options(step_options) do
    {:ok, step_options}
  end

  def run(input_param, _opts) do
    raw_data = Param.get_payload(input_param)
    processed = Enum.map(raw_data, &(&1 <> "_denoised"))
    {:ok, Param.new(:clean_vocal, :audio) |> Param.set_payload(processed)}
  end
end

defmodule Orchid.TestSteps.PitchFix do
  use Orchid.Step
  alias Orchid.Param

  def run(input_param, _opts) do
    data = Param.get_payload(input_param)
    processed = Enum.map(data, &(&1 <> "_tuned"))
    {:ok, Param.new(:tuned_vocal, :audio) |> Param.set_payload(processed)}
  end
end

defmodule Orchid.TestSteps.Mix do
  use Orchid.Step
  alias Orchid.Param

  def run([vocal_param, bgm_param], _opts) do
    vocal = Param.get_payload(vocal_param)
    bgm = Param.get_payload(bgm_param)

    mixed = Enum.zip_with(vocal, bgm, fn v, b -> "Mix[#{v} + #{b}]" end)
    {:ok, Param.new(:final_track, :audio) |> Param.set_payload(mixed)}
  end
end
