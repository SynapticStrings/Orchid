# See https://chat.deepseek.com/share/zd94ty8o0ulu18mgh1 to view the conversation that led to this code.
# It's has some modifications to the original code, but it should be mostly the same.
# Powered by DeepSeek (https://deepseek.com) in 12th Feb, 2026(before Spring Festival).

defmodule OrchidIntegrationTest do
  use ExUnit.Case, async: true

  # ----------------------------------------------------------------------------
  # Test Steps
  # ----------------------------------------------------------------------------

  defmodule Grind do
    use Orchid.Step
    alias Orchid.Param

    @impl true
    def run(%Param{payload: beans}, opts) do
      ratio = Keyword.get(opts, :ratio, 1)
      {:ok, Param.new(:powder, :solid, beans * ratio)}
    end
  end

  defmodule Brew do
    use Orchid.Step
    alias Orchid.Param

    @impl true
    def run([powder, water], opts) do
      style = Keyword.get(opts, :style, :espresso)
      p = Param.get_payload(powder)
      w = Param.get_payload(water)
      {:ok, Param.new(:coffee, :liquid, "Cup of #{style} (#{p}g / #{w}ml)")}
    end
  end

  defmodule BaggageStep do
    use Orchid.Step
    alias Orchid.Param
    alias Orchid.Runner.Hooks.Core

    @impl true
    def run(_input, opts) do
      ctx = Core.extract_workflow_ctx(opts)
      trace_id = Orchid.WorkflowCtx.get_baggage(ctx, :trace_id, "none")
      {:ok, Param.new(:trace, :string, trace_id)}
    end
  end

  defmodule ErrorStep do
    use Orchid.Step
    @impl true
    def run(_input, _opts), do: {:error, "oops"}
  end

  defmodule TupleStep do
    use Orchid.Step
    alias Orchid.Param

    @impl true
    def run([%Param{payload: a}, %Param{payload: b}], _opts) do
      {:ok, Param.new(:sum, :integer, a + b)}
    end
  end

  # ----------------------------------------------------------------------------
  # Test Hooks & Operons
  # ----------------------------------------------------------------------------

  # A step‑level hook that sends a message to the test process
  defmodule CaptureHook do
    @behaviour Orchid.Runner.Hook

    @impl true
    def call(ctx, next) do
      send(self(), {:hook_called, ctx.step_implementation})
      next.(ctx)
    end
  end

  # A recipe‑level operon that injects a missing Grind step
  defmodule InjectGrindOperon do
    @behaviour Orchid.Operon
    alias Orchid.Operon.Request

    @impl true
    def call(%Request{recipe: recipe} = req, next) do
      # Prepend a Grind step that produces :powder from :beans
      new_steps = [{Grind, :beans, :powder} | recipe.steps]
      new_recipe = %{recipe | steps: new_steps}
      next.(%{req | recipe: new_recipe})
    end
  end

  # ----------------------------------------------------------------------------
  # Integration Tests
  # ----------------------------------------------------------------------------

  describe "basic recipe execution" do
    test "serial executor runs steps in dependency order" do
      inputs = [
        Orchid.Param.new(:beans, :raw, 20),
        Orchid.Param.new(:water, :raw, 200)
      ]

      # Steps defined out of order – Orchid must topologically sort them
      steps = [
        {Brew, [:powder, :water], :coffee, [style: :latte]},
        {Grind, :beans, :powder, [ratio: 1]}
      ]

      recipe = Orchid.Recipe.new(steps, name: :morning_coffee)

      assert {:ok, results} =
               Orchid.run(recipe, inputs,
                 executor_and_opts: {Orchid.Executor.Serial, []}
               )

      assert %{coffee: coffee} = results
      assert Orchid.Param.get_payload(coffee) =~ "Cup of latte (20g / 200ml)"
    end

    test "async executor runs independent steps concurrently" do
      inputs = [
        Orchid.Param.new(:beans_a, :raw, 10),
        Orchid.Param.new(:beans_b, :raw, 15)
      ]

      steps = [
        {Grind, :beans_a, :powder_a},
        {Grind, :beans_b, :powder_b}
      ]

      recipe = Orchid.Recipe.new(steps)

      assert {:ok, results} =
               Orchid.run(recipe, inputs,
                 executor_and_opts: {Orchid.Executor.Async, [concurrency: 2]}
               )

      assert %{powder_a: a, powder_b: b} = results
      assert Orchid.Param.get_payload(a) == 10
      assert Orchid.Param.get_payload(b) == 15
    end
  end

  describe "nested steps" do
    test "implicit mapping works" do
      inner_steps = [{Grind, :beans, :powder}]
      inner_recipe = Orchid.Recipe.new(inner_steps)

      parent_steps = [
        {Orchid.Step.NestedStep, :beans, :powder, [recipe: inner_recipe]},
        {Brew, [:powder, :water], :coffee}
      ]

      inputs = [
        Orchid.Param.new(:beans, :raw, 30),
        Orchid.Param.new(:water, :raw, 300)
      ]

      assert {:ok, results} = Orchid.run(parent_steps, inputs)
      assert %{coffee: coffee} = results
      assert Orchid.Param.get_payload(coffee) =~ "Cup of espresso (30g / 300ml)"
    end

    test "explicit mapping with input_map and output_map" do
      inner_steps = [{Grind, :inner_beans, :inner_powder}]
      inner_recipe = Orchid.Recipe.new(inner_steps)

      parent_steps = [
        {Orchid.Step.NestedStep, :beans_for_grinding, :powder_result,
         [
           recipe: inner_recipe,
           input_map: %{beans_for_grinding: :inner_beans},
           output_map: %{inner_powder: :powder_result}
         ]},
        {Brew, [:powder_result, :water], :coffee}
      ]

      inputs = [
        Orchid.Param.new(:beans_for_grinding, :raw, 40),
        Orchid.Param.new(:water, :raw, 400)
      ]

      assert {:ok, results} = Orchid.run(parent_steps, inputs)
      assert %{coffee: coffee} = results
      assert Orchid.Param.get_payload(coffee) =~ "Cup of espresso (40g / 400ml)"
    end
  end

  describe "hooks" do
    test "step-level hook is executed" do
      inputs = [Orchid.Param.new(:beans, :raw, 50)]

      steps = [
        {Grind, :beans, :powder, [extra_hooks_stack: [CaptureHook]]}
      ]

      recipe = Orchid.Recipe.new(steps)

      # Hook sends message to the test process
      # Make sure Runner and linster are in same process so we receive the message
      assert {:ok, %{powder: _}} = Orchid.run(recipe, inputs, executor_and_opts: {Orchid.Executor.Serial, []})
      assert_receive {:hook_called, Grind}
    end

    test "global hooks stack is applied to every step" do
      inputs = [Orchid.Param.new(:beans, :raw, 50)]

      steps = [
        {Grind, :beans, :powder}
      ]

      recipe = Orchid.Recipe.new(steps)

      assert {:ok, %{powder: _}} =
               Orchid.run(recipe, inputs, global_hooks_stack: [CaptureHook], executor_and_opts: {Orchid.Executor.Serial, []})

      assert_receive {:hook_called, Grind}
    end
  end

  describe "operons (recipe-level middleware)" do
    test "operon can inject steps before execution" do
      inputs = [
        Orchid.Param.new(:beans, :raw, 60),
        Orchid.Param.new(:water, :raw, 600)
      ]

      # Recipe without Grind – Brew would fail because :powder is missing
      steps = [
        {Brew, [:powder, :water], "coffee"}
      ]

      recipe = Orchid.Recipe.new(steps)

      # InjectGrindOperon prepends a Grind step that produces :powder
      assert {:ok, %{"coffee" => coffee}} =
               Orchid.run(recipe, inputs,
                 operons_stack: [InjectGrindOperon]
               )

      assert Orchid.Param.get_payload(coffee) =~ "Cup of espresso (60g / 600ml)"
    end
  end

  describe "baggage propagation" do
    test "baggage is accessible inside steps" do
      inputs = [Orchid.Param.new("dummy", :any, nil)]
      steps = [{BaggageStep, "dummy", :trace}]
      recipe = Orchid.Recipe.new(steps)

      assert {:ok, %{trace: trace_param}} =
               Orchid.run(recipe, inputs, baggage: %{trace_id: "abc-123"})

      assert Orchid.Param.get_payload(trace_param) == "abc-123"
    end
  end

  describe "error handling" do
    test "step failure returns Orchid.Error with reason and step id" do
      inputs = [Orchid.Param.new("dummy", :any, nil)]
      steps = [{ErrorStep, "dummy", "result"}]
      recipe = Orchid.Recipe.new(steps)

      assert {:error, %Orchid.Error{reason: "oops", step_id: step_id}} =
               Orchid.run(recipe, inputs)

      assert step_id == {MapSet.new(["dummy"]), MapSet.new(["result"])}
    end

    test "missing input validation fails with {:error, {:missing_inputs, _}}" do
      steps = [{Grind, "beans", "powder"}]
      # No input for "beans"
      assert {:error, %Orchid.Error{reason: {:missing_inputs, _}}} = Orchid.run(steps, [])
    end

    test "cyclic dependency validation fails with {:error, {:cyclic, _}}" do
      steps = [
        {Grind, "b", "a"},
        {Grind, "a", "b"}
      ]
      assert {:error, %Orchid.Error{reason: {:cyclic, _}}} = Orchid.run(steps, [])
    end
  end

  describe "option assignment" do
    test "Recipe.assign_options modifies step options" do
      steps = [
        {Grind, "beans", "powder", [ratio: 1]}
      ]
      recipe = Orchid.Recipe.new(steps)

      # Change ratio to 2
      recipe2 = Orchid.Recipe.assign_options(recipe, Grind, ratio: 2)

      inputs = [Orchid.Param.new("beans", :raw, 10)]
      assert {:ok, %{"powder" => powder}} = Orchid.run(recipe2, inputs)
      assert Orchid.Param.get_payload(powder) == 20
    end
  end

  describe "tuple input / output" do
    test "step receives input keys as tuple but requires list inputs" do
      inputs = [
        Orchid.Param.new("a", :integer, 3),
        Orchid.Param.new("b", :integer, 5)
      ]

      steps = [
        {TupleStep, {"a", "b"}, "sum"}
      ]

      recipe = Orchid.Recipe.new(steps)
      assert {:ok, %{"sum" => sum}} = Orchid.run(recipe, inputs)
      assert Orchid.Param.get_payload(sum) == 8
    end
  end

  describe "return_response option" do
    test "when true, returns full Response struct instead of payload" do
      inputs = [Orchid.Param.new("beans", :raw, 20)]
      steps = [{Grind, "beans", "powder"}]
      recipe = Orchid.Recipe.new(steps)

      assert %Orchid.Operon.Response{payload: {:ok, %{"powder" => _}}} =
               Orchid.run(recipe, inputs, return_response: true)
    end
  end
end
