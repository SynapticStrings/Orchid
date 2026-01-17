defmodule Orchid.WorkflowCtxTest do
  use ExUnit.Case

  alias Orchid.WorkflowCtx, as: Ctx

  # just to make coverage 100%
  test "get_baggage/3 can get content" do
    ctx =
      Ctx.new()
      |> Ctx.merge_baggage(%{foo: :bar})

    assert Ctx.get_baggage(ctx, :foo) == :bar

    assert Ctx.get_baggage(ctx, :bar) == :nil
  end
end
