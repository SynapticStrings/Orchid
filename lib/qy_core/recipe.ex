defmodule QyCore.Recipe do
  @moduledoc """
  定义一个处理流程（菜谱）。

  ### Recipe options

  关于分配参数：TBD
  """

  alias QyCore.{Recipe, Step}
  alias QyCore.Step.NestedStep

  @type t :: %__MODULE__{
          steps: [Step.t()],
          name: atom() | nil,
          opts: keyword()
        }
  defstruct steps: [], name: nil, opts: []

  @spec new([Step.t()], keyword()) :: t()
  def new(steps, opts \\ []) do
    # TODO: 这里可以做更多的验证和预处理
    %__MODULE__{
      steps: steps,
      name: Keyword.get(opts, :name),
      opts: opts
    }
  end

  @doc """
  全局注入选项 (支持深度注入以及更新配置)。

  ### selector 的选项

  * 模块或函数本体 => 匹配就可以
  * 检查函数 => 输入 step ，自定义具体逻辑
  """
  @spec assign_options(
          QyCore.Recipe.t(),
          Step.implementation() | (Step.t() -> boolean()),
          keyword() | %{}
        ) :: QyCore.Recipe.t()
  def assign_options(%__MODULE__{} = recipe, selector, new_opts) do
    %{
      recipe
      | steps:
          walk(recipe.steps, fn step ->
            step
            |> do_match(selector)
            |> if(do: Step.inject_options(Step.ensure_full_step(step), new_opts), else: step)
          end)
    }
  end

  @doc """
  对 step 列表进行深度遍历。

  因为 QyCore.Scheduler.update_pending_steps_options/3 的存在，要考虑列表的存在。

  func 会被应用到树中的每一个 Step 或 Recipe 上。
  如果 Step 是 NestedStep ，会自动递归进入其内部的 step 列表。
  """
  @spec walk(
          [Step.t()],
          (Step.t() -> Step.t()) | (Recipe.t() -> Recipe.t()),
          :step | :inner_recipe
        ) :: [Step.t()]
  def walk(steps, func, mode \\ :step)

  def walk(steps, func, :step) when is_function(func, 1) do
    Enum.map(steps, fn step ->
      modified_step = func.(step)

      process_nested(modified_step, func, :step)
    end)
  end

  def walk(steps, func, :inner_recipe) when is_function(func, 1) do
    Enum.map(steps, fn step ->
      modified_step = func.(step)

      process_nested(modified_step, func, :inner_recipe)
    end)
  end

  defp process_nested(step, func, mode) do
    {impl, in_k, out_k, opts} = Step.ensure_full_step(step)

    with true <- NestedStep.nested?(step),
         %__MODULE__{} = inner_recipe <- Keyword.get(opts, :recipe) do
      new_opts = Keyword.put(opts, :recipe, replace_nested_steps(inner_recipe, func, mode))
      {impl, in_k, out_k, new_opts}
    else
      _ -> step
    end
  end

  defp replace_nested_steps(inner_recipe, func, :step) do
    %{
      inner_recipe
      | steps: walk(inner_recipe.steps, func, :step)
    }
  end

  defp replace_nested_steps(inner_recipe, func, :inner_recipe) do
    new_inner_recipe = func.(inner_recipe)

    %{new_inner_recipe | steps: walk(new_inner_recipe.steps, func, :inner_recipe)}
  end

  defp do_match(step, selector) when is_atom(selector) or is_function(selector, 2) do
    {impl, _in_k, _out_k, _current_opts} = Step.ensure_full_step(step)

    case selector do
      :all -> true
      # 匹配模块
      ^impl -> true
      _ -> false
    end
  end

  defp do_match(step, selector) when is_function(selector, 1) do
    selector.(step)
  end
end
