defmodule Orchid.StepTest do
  use ExUnit.Case
  alias Orchid.Step

  describe "step provides API" do
    test "extract_schema/1 remove options" do
      step = {Foo, :i, :o, [foo: :bar]}

      {Foo, :i, :o} = Step.extract_schema(step)
    end

    test "ensure_full_step/1 inject blank options automatically when no options" do
      step = {Foo, :i, :o}

      {_, _, _, []} = Step.ensure_full_step(step)
    end

    test "inject_options/2 allowed keyword and map" do
      kv_opts = [foo: :bar]
      map_opts = %{foo: :bar, a: :aha}

      step = {Foo, [:i1, :i2], {:o1, :o2, :o3}}

      {_, _, _, options_from_keyword} = Step.inject_options(step, kv_opts)
      assert Keyword.get(options_from_keyword, :foo) == :bar

      {_, _, _, options_from_map} = Step.inject_options(step, map_opts)
      assert Keyword.get(options_from_map, :foo) == :bar
    end
  end

  describe "Orchid.Runner.Hooks.Core runs step" do
    # ...
  end
end
