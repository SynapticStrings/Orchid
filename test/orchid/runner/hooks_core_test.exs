defmodule Orchid.Runner.HooksCoreTest do
  use ExUnit.Case

  alias Orchid.Param
  alias Orchid.Runner.Hooks.Core

  defp load_context({impl, input_keys, output_keys, step_opts}, params_map) do
    %Orchid.Runner.Context{
      step_implementation: impl,
      in_keys: input_keys,
      out_keys: output_keys,
      step_opts: step_opts,
      inputs: params_map,
      recipe_opts: [],
      telemetry_meta: %{impl: impl, in_keys: input_keys, out_keys: output_keys},
      workflow_ctx: Orchid.WorkflowCtx.new(),
      assigns: %{}
    }
  end

  describe "call/2 implement behavoir" do
    test "contains call/2" do
      assert function_exported?(Core, :call, 2)
    end
  end

  describe "workflow_context passthough via options" do
    # ...
  end

  describe "make name and param correspond" do
    test "has tuple contained" do
      step_with_tuple_output = fn _, _ -> {:ok, {Param.new(:bar, :void, nil)}} end
      step_with_param_output = fn _, _ -> {:ok, Param.new(:bar, :void, nil)} end

      {:ok, _} =
        Core.call(
          load_context({step_with_tuple_output, :foo, {:bar}, []}, %{
            foo: Param.new(:inputs, :void, nil)
          }),
          fn _ -> {:error, :touch_fin} end
        )

      {:ok, _} =
        Core.call(
          load_context({step_with_tuple_output, :foo, :bar, []}, %{
            foo: Param.new(:inputs, :void, nil)
          }),
          fn _ -> {:error, :touch_fin} end
        )

      {:ok, _} =
        Core.call(
          load_context({step_with_param_output, :foo, {:bar}, []}, %{
            foo: Param.new(:inputs, :void, nil)
          }),
          fn _ -> {:error, :touch_fin} end
        )
    end

    test "single output" do
      # as atom
      step_with_atom_key = {
        fn _, _ -> {:ok, Param.new(:bar, :void, nil)} end,
        :foo,
        :bar,
        []
      }

      {:ok, _} =
        Core.call(
          load_context(step_with_atom_key, %{foo: Param.new(:inputs, :void, nil)}),
          fn _ -> {:error, :touch_fin} end
        )

      # as [atom]
      step_with_list_key = {
        fn _, _ -> {:ok, Param.new(:bar, :void, nil)} end,
        :foo,
        [:bar],
        []
      }

      {:ok, _} =
        Core.call(
          load_context(step_with_list_key, %{foo: Param.new(:inputs, :void, nil)}),
          fn _ -> {:error, :touch_fin} end
        )
    end

    test "lists & lists" do
      # single
      single_step = fn _, _ -> {:ok, [Param.new(:out, :void, nil)]} end

      {:ok, %Param{}} = Core.call(
          load_context({single_step, :inputs, [:out], []}, %{foo: Param.new(:inputs, :void, nil)}),
          fn _ -> {:error, :touch_fin} end
        )

      # multi
      # The Order is important
      multi_step = fn _, _ -> {:ok, [Param.new(:o2, :void, :nil_1), Param.new(:o1, :void, :nil_2)]} end

      {:ok, [%Param{}, %Param{}]} =
        Core.call(
          load_context({multi_step, :inputs, [:_1, :_2], []}, %{foo: Param.new(:inputs, :void, nil)}),
          fn _ -> {:error, :touch_fin} end
        )
    end
  end

  describe "running step" do
    # test "normal_steps"

    test "invalid_step_implementation" do
      assert {:error, {:invalid_step_implementation, _}} =
               Core.call(
                 load_context({Foo, :i, :o, []}, %{i: Param.new(:inputs, :void, nil)}),
                 fn _ -> {nil, :void} end
               )

      assert {:error, {:invalid_step_implementation, _}} =
               Core.call(
                 load_context({"可真有意思。", :i, :o, []}, %{i: Param.new(:inputs, :void, nil)}),
                 fn _ -> {nil, :void} end
               )
    end
  end
end
