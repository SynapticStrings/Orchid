defmodule NoteParser do
  :ok = Application.ensure_loaded(:qy_music)

  # 1. BPM & beat -> absolutely time
  # 2. Note -> Pitch

  @timestep 0.05

  def init do
    %{time_step: @timestep}
  end

  def call({note_sequence}, _opts) do
    {note_sequence}
  end
end

defmodule PitchChangeWhenNoteChange do
  # A helper to flattern the pitch
  # change of note
end

defmodule Pitch2Waveform do
  # ...
end
