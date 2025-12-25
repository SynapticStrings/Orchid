defmodule Orchid.RecipeTest do
  use ExUnit.Case
  alias Orchid.{Recipe, Step}
  alias Orchid.Step.NestedStep

  # 定义一些简单的 Step 用于测试
  defmodule TestStepA do
    use Orchid.Step
    def run(p, _), do: {:ok, p}
  end

  defmodule TestStepB do
    use Orchid.Step
    @impl true
    def run(p, _), do: {:ok, p}
  end

  defmodule TestStepC do
    use Orchid.Step
    @impl true
    def nested?(), do: true
    @impl true
    def run(p, _), do: {:ok, p}
  end

  describe "assign_options/3 coverage" do
    test "applies options to all steps using :all selector" do
      # Coverage: Line 135 (:all -> true)
      steps = [
        {TestStepA, :in, :out},
        {TestStepB, :in, :out}
      ]

      recipe = Recipe.new(steps)

      updated_recipe = Recipe.assign_options(recipe, :all, trace_id: "global")

      # 验证所有步骤都被注入了选项
      assert Enum.all?(updated_recipe.steps, fn step ->
               {_, _, _, opts} = Step.ensure_full_step(step)
               opts[:trace_id] == "global"
             end)
    end

    test "applies options using a function selector" do
      # Coverage: Line 143 (selector.(step))
      steps = [
        {TestStepA, :in, :out, [tag: :keep]},
        {TestStepB, :in, :out, [tag: :ignore]}
      ]

      recipe = Recipe.new(steps)

      # 自定义选择器：只选择 tag 为 :keep 的步骤
      selector = fn step ->
        {_, _, _, opts} = Step.ensure_full_step(step)
        opts[:tag] == :keep
      end

      updated_recipe = Recipe.assign_options(recipe, selector, injected: true)

      [step1, step2] = updated_recipe.steps
      {_, _, _, opts1} = Step.ensure_full_step(step1)
      {_, _, _, opts2} = Step.ensure_full_step(step2)

      assert opts1[:injected] == true
      assert opts2[:injected] == nil
    end
  end

  describe "walk/3 with :inner_recipe mode" do
    test "recursively modifies ONLY inner recipes, leaving enclosing steps untouched" do
      inner_recipe = Recipe.new([{TestStepA, :child_in, :child_out}], name: :original_child)

      nested_step =
        {NestedStep, :parent_in, :parent_out, [recipe: inner_recipe, tag: :outer_step]}

      outer_recipe = Recipe.new([nested_step], name: :original_parent)

      recipe_transform = fn %Recipe{} = r ->
        %{r | name: String.to_atom("modified_#{r.name}")}
      end

      modified_steps = Recipe.walk(outer_recipe.steps, recipe_transform, :inner_recipe)

      [modified_nested_step] = modified_steps
      {_, _, _, outer_opts} = Step.ensure_full_step(modified_nested_step)

      assert outer_opts[:tag] == :outer_step

      modified_inner_recipe = outer_opts[:recipe]
      assert modified_inner_recipe.name == :modified_original_child

      # 只要 Recipe 被修改了，说明递归逻辑是通的。
      # 注意：因为 recipe_transform 只改 Recipe 名字，不改 Step，
      # 所以这里不需要检查 inner_step 是否有变化，只要检查 recipe 结构体本身即可。
    end

    test "handles indexed steps tuple format {step, idx} transparently" do
      # 验证带索引的遍历是否正常
      step = {TestStepC, :in, :out, [recipe: Recipe.new([], name: :sub)]}
      indexed_steps = [{step, 0}]

      transform = fn %Recipe{} = r -> %{r | name: :changed} end

      # 执行
      result = Recipe.walk(indexed_steps, transform, :inner_recipe)

      # 验证结果
      [{modified_step, 0}] = result
      {_, _, _, opts} = Step.ensure_full_step(modified_step)

      assert opts[:recipe].name == :changed
    end
  end

  describe "assign_options/3 use walk/3" do
    test "assign_options penetrates into nested recipes" do
      inner_recipe =
        Recipe.new([
          {TestStepB, :in, :out}
        ])

      middle_steps = [
        {NestedStep, :a, :b, [recipe: inner_recipe]}
      ]

      middle_recipe = Recipe.new(middle_steps)

      outer_steps = [
        {NestedStep, :x, :y, [recipe: middle_recipe]}
      ]

      outer_recipe = Recipe.new(outer_steps)

      updated_recipe = Recipe.assign_options(outer_recipe, TestStepB, sample_rate: 48000)

      {_, _, _, opts1} = hd(updated_recipe.steps)
      middle = opts1[:recipe]

      {_, _, _, opts2} = hd(middle.steps)
      inner = opts2[:recipe]

      {impl, _, _, final_opts} = hd(inner.steps)

      assert impl == TestStepB
      assert final_opts[:sample_rate] == 48000
    end
  end
end
