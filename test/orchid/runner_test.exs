defmodule Orchid.RunnerTest do
  use ExUnit.Case

  # TODO: seperate into
  # building runner context
  # and
  # run pipelines
  # two parts
  describe "run/3" do
    setup do
      [
        mock_pipe_hook: fn ctx, next_fn -> next_fn.(ctx) end,
        mock_terminal_hook: fn ctx, _ -> {:ok, Orchid.Param.new(:res, :context, ctx)} end
      ]
    end

    test "building runner context successed when private prepare_inputs/2 works" do
      # ...
    end

    test "run pipelines will return error when no hooks exist" do
      # ...
    end
  end
end
