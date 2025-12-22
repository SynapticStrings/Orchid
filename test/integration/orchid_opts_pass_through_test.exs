defmodule Orchid.OptsPassThroughTest do
  use ExUnit.Case, async: true

  for hook_name <- [MockHookA, MockHookB] do
    Module.create(
      hook_name,
      quote do
        use Orchid.TestHelpers.HookFactory
      end,
      Macro.Env.location(__ENV__)
    )
  end

  alias Orchid.Executor.Serial, as: MockExecutorParent
  alias Orchid.Executor.Serial, as: MockExecutorChild

  # Send running opts into test process
  defmodule InspectorStep do
    use Orchid.Step

    def run(_input, opts) do
      # Catch ALL envs within that step
      send(self(), {:inspector_report, opts})
      {:ok, Orchid.Param.new(:result, :void, :ok)}
    end
  end

  test "verify nested options inheritance logic" do
    inner_steps = [{InspectorStep, :ignore, :result}]

    inner_recipe =
      Orchid.Recipe.new(inner_steps,
        name: :inner,
        global_hooks_stack: [MockHookB],
        executor_and_opts: {MockExecutorChild, []}
      )

    parent_steps = [
      {Orchid.Step.NestedStep, :start, :end,
       [recipe: inner_recipe, input_map: %{start: :ignore}, output_map: %{result: :end}]}
    ]

    parent_recipe = Orchid.Recipe.new(parent_steps, name: :parent)

    parent_run_opts = [
      global_hooks_stack: [MockHookA],
      executor_and_opts: {MockExecutorParent, []}
    ]

    initial_params = [Orchid.Param.new(:start, :void, nil)]

    Orchid.run(parent_recipe, initial_params, parent_run_opts)

    assert_received {:inspector_report, received_opts}

    hooks = Keyword.get(received_opts, :global_hooks_stack)

    assert hooks == [MockHookA, MockHookB],
           "Hooks should be stacked: Parent first, then Child. Got: #{inspect(hooks)}"

    {executor, _} = Keyword.get(received_opts, :executor_and_opts)

    assert executor == MockExecutorChild,
           "Executor should be overridden by Inner Recipe. Got: #{inspect(executor)}"
  end

  test "verify nested options inheritance when Child is empty" do
    inner_steps = [{InspectorStep, :ignore, :result}]
    inner_recipe = Orchid.Recipe.new(inner_steps, name: :inner_empty)

    parent_steps = [
      {Orchid.Step.NestedStep, :start, :end,
       [recipe: inner_recipe, input_map: %{start: :ignore}, output_map: %{result: :end}]}
    ]

    parent_recipe = Orchid.Recipe.new(parent_steps, name: :parent)

    parent_run_opts = [
      global_hooks_stack: [MockHookA],
      executor_and_opts: {MockExecutorParent, []}
    ]

    Orchid.run(parent_recipe, [Orchid.Param.new(:start, :void, nil)], parent_run_opts)

    assert_received {:inspector_report, received_opts}

    assert Keyword.get(received_opts, :global_hooks_stack) == [MockHookA]
    assert elem(Keyword.get(received_opts, :executor_and_opts), 0) == MockExecutorParent
  end
end
