defmodule Orchid.RunnerHooks.CoreTest do
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

  defp build_ctx(out_keys, return_value) do
    dummy_impl = fn _inputs, _opts -> {:ok, return_value} end

    load_context({dummy_impl, [], out_keys, []}, [])
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

      {:ok, %Param{}} =
        Core.call(
          load_context({single_step, :inputs, [:out], []}, %{foo: Param.new(:inputs, :void, nil)}),
          fn _ -> {:error, :touch_fin} end
        )

      # multi
      # The Order is important
      multi_step = fn _, _ ->
        {:ok, [Param.new(:o2, :void, :nil_1), Param.new(:o1, :void, :nil_2)]}
      end

      {:ok, [%Param{}, %Param{}]} =
        Core.call(
          load_context({multi_step, :inputs, [:_1, :_2], []}, %{
            foo: Param.new(:inputs, :void, nil)
          }),
          fn _ -> {:error, :touch_fin} end
        )
    end

    test "Supports Map output directly" do
      raw_output = %{
        target: Param.new(:target, :string, "success")
      }

      ctx = build_ctx({:target}, raw_output)

      {:ok, [result]} = Core.call(ctx, fn _ -> :ok end)

      assert result.payload == "success"
    end

    test "Scenario 5: Raises error if Map key missing" do
      raw_output = %{
        other: Param.new(:other, :string, "val")
      }

      ctx = build_ctx(:missing_key, raw_output)

      assert_raise ArgumentError, ~r/Step output missing key/, fn ->
        Core.call(ctx, fn _ -> :ok end)
      end
    end

    test "[Error] Raises ArgumentError on ambiguous multiple returns" do
      raw_output = [
        Param.new(:foo, :string, "a"),
        Param.new(:bar, :string, "b")
      ]

      ctx = build_ctx(:baz, raw_output)

      assert_raise ArgumentError, ~r/Ambiguous step output/, fn ->
        Core.call(ctx, fn _ -> :ok end)
      end
    end
  end

  describe "running step" do
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

  defmodule RefStore do
    @behaviour Orchid.Repo

    use Agent

    def start_link(_), do: Agent.start_link(fn -> %{} end)

    def put(repo, key, val), do: Agent.update(repo, &Map.put(&1, key, val))

    def get(repo, key) do
      case Agent.get(repo, &Map.fetch(&1, key)) do
        {:ok, val} -> {:ok, val}
        :error -> :miss
      end
    end
  end

  describe "ref payload hydration" do
    setup do
      {:ok, store} = RefStore.start_link(nil)
      :ok = Orchid.Repo.dispatch_store({RefStore, store}, :put, ["hash-a", 42])
      :ok = Orchid.Repo.dispatch_store({RefStore, store}, :put, ["hash-b", "raw"])
      %{store: {RefStore, store}}
    end

    test "ref payloads in map inputs are resolved before the step runs", %{store: store} do
      echo = fn inputs, _opts -> {:ok, inputs} end

      {:ok, %Param{payload: 42}} =
        Core.call(
          load_context({echo, :foo, :foo, []}, %{
            foo: Param.new(:foo, :void, {:ref, store, "hash-a"})
          }),
          fn _ -> {:error, :touch_fin} end
        )
    end

    test "ref payloads in list inputs are resolved", %{store: store} do
      echo = fn inputs, _opts -> {:ok, inputs} end

      {:ok, [%Param{payload: 42}, %Param{payload: "raw"}]} =
        Core.call(
          load_context({echo, :inputs, [:a, :b], []}, [
            Param.new(:a, :void, {:ref, store, "hash-a"}),
            Param.new(:b, :void, {:ref, store, "hash-b"})
          ]),
          fn _ -> {:error, :touch_fin} end
        )
    end

    test "a bare ref param input is resolved", %{store: store} do
      echo = fn inputs, _opts -> {:ok, inputs} end

      {:ok, %Param{payload: "raw"}} =
        Core.call(
          load_context({echo, :in, :out, []}, Param.new(:in, :void, {:ref, store, "hash-b"})),
          fn _ -> {:error, :touch_fin} end
        )
    end

    test "a missing blob raises instead of leaking the ref", %{store: store} do
      echo = fn inputs, _opts -> {:ok, inputs} end

      assert_raise RuntimeError, ~r/Hydration failed/, fn ->
        Core.call(
          load_context({echo, :foo, :foo, []}, %{
            foo: Param.new(:foo, :void, {:ref, store, "missing"})
          }),
          fn _ -> {:error, :touch_fin} end
        )
      end
    end
  end
end
