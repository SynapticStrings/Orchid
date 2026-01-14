defmodule Orchid.RunnerTest do
  alias Orchid.{Param, WorkflowCtx}
  use ExUnit.Case

  defmodule Bar do
    use Orchid.Step

    def run(_input, _step_options) do
      {:ok, Orchid.Param.new(:output, :void, nil)}
    end
  end

  defmodule PassThroughHook do
    @behaviour Orchid.Runner.Hook
    def call(ctx, next), do: next.(ctx)
  end

  # TODO: seperate into
  # building runner context
  # and
  # run pipelines
  # two parts
  describe "run/3" do
    setup do
      [
        mock_pipe_hook: fn ctx, next_fn -> next_fn.(ctx) end,
        mock_terminal_hook: fn ctx, _ -> {:ok, Param.new(:res, :context, ctx)} end
      ]
    end

    test "building runner context successed when private prepare_inputs/2 works" do
      # In inner Orchid
      # All steps must be 4 items
      step = {Bar, {:i1, :i2}, :o3, []}

      ctx_params = %{
        i1: Param.new(:i1, :void, nil),
        i2: Param.new(:i2, :void, nil)
      }

      {:ok, _} = Orchid.Runner.run(step, ctx_params, [], WorkflowCtx.new())
    end

    test "run pipelines will return error when no hooks exist" do
      step = {Bar, {:i1, :i2}, :o3, []}
      ctx_params = %{
        i1: Param.new(:i1, :void, nil),
        i2: Param.new(:i2, :void, nil)
      }

      workflow_ctx = WorkflowCtx.new()
      |> WorkflowCtx.merge_config(%{core_hook: PassThroughHook})

      result = Orchid.Runner.run(step, ctx_params, [], workflow_ctx)

      assert result == {:error, :no_executor_hook}
    end
  end
end
