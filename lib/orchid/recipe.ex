defmodule Orchid.Recipe do
  @moduledoc """
  定义一个处理流程（菜谱）。

  ### Recipe options

  * `:recipe` （需要是模块且回调的 nested? 为真）
  """

  alias Orchid.{Recipe, Step}
  alias Orchid.Step.NestedStep

  @type t :: %__MODULE__{
          steps: [Step.t()],
          name: atom() | nil,
          opts: keyword()
        }
  defstruct steps: [], name: nil, opts: []

  @spec new([Step.t()], keyword()) :: t()
  def new(steps, opts \\ []) do
    %__MODULE__{
      steps: steps,
      name: Keyword.get(opts, :name),
      opts: opts
    }
  end

  @spec validate_steps([Step.t()], [atom()]) :: :ok | {:error, term()}
  def validate_steps(steps, initial_keys) do
    with [] <- get_step_errors(steps),
         :ok <- detect_missing_inputs(steps, initial_keys),
         :ok <- detect_cycles(steps, initial_keys) do
      :ok
    else
      {:error, {:missing_inputs, missing_map}} ->
        {:error, {:missing_inputs, missing_map}}

      {:error, {:cyclic, cyclic_indices}} ->
        {:error, {:cyclic, cyclic_indices}}

      validate_errors ->
        {:error, {:option_validation_failed, validate_errors}}
    end
  end

  defp detect_missing_inputs(steps, initial_keys) do
    Recipe.Graph.check_missing_initial(steps, initial_keys)
  end

  defp detect_cycles(steps, initial_keys) do
    Recipe.Graph.check_cycles(steps, initial_keys)
  end

  @spec get_step_errors([Step.t()]) :: [] | [term()]
  defp get_step_errors(steps) do
    steps
    |> Enum.with_index()
    |> Enum.reduce([], fn {step, idx}, acc ->
      {impl, _, _, opts} = Orchid.Step.ensure_full_step(step)

      # 检查模块是否导出了 validate/1
      if is_atom(impl) and Code.ensure_loaded?(impl) and
           function_exported?(impl, :validate_options, 1) do
        case impl.validate_options(opts) do
          :ok -> acc
          {:error, reason} -> [{:invalid_step_option, idx, impl, reason} | acc]
        end
      else
        acc
      end
    end)
  end

  @doc """
  全局注入选项 (支持深度注入以及更新配置)。

  ### selector 的选项

  * 模块或函数本体 => 匹配就可以
  * 检查函数 => 输入 step ，自定义具体逻辑
  """
  @spec assign_options(
          Orchid.Recipe.t(),
          Step.implementation() | (Step.t() -> boolean()),
          keyword() | %{}
        ) :: Orchid.Recipe.t()
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

  因为 Orchid.Scheduler.inject_opts/3 的存在，要考虑附带索引的列表的存在。

  func 会被应用到树中的每一个 Step 或 Recipe 上。
  如果 Step 是 NestedStep ，会自动递归进入其内部的 step 列表或对该 recipe 本体进行修改。

  ### 模式

  * `:step` - 对 Step 进行修改
  * `:inner_recipe` - 内部的 NestedStep 的 Recipe 结构体进行修改
  """
  @spec walk(
          [Step.t()] | [{Step.t(), non_neg_integer()}],
          (Step.t() -> Step.t()) | (Recipe.t() -> Recipe.t()),
          :step | :inner_recipe
        ) :: [Step.t()]
  def walk(steps, func, mode \\ :step)

  def walk(steps, func, :step) do
    Enum.map(steps, fn
      {step, idx} -> {do_walk_step(step, func), idx}
      step -> do_walk_step(step, func)
    end)
  end

  def walk(steps, func, :inner_recipe) do
    Enum.map(steps, fn
      {step, idx} -> {do_walk_inner_recipe(step, func), idx}
      step -> do_walk_inner_recipe(step, func)
    end)
  end

  defp do_walk_step(step, func) do
    modified_step = func.(step)

    if NestedStep.nested?(modified_step) do
      update_inner_recipe(modified_step, fn inner_recipe ->
        %{inner_recipe | steps: walk(inner_recipe.steps, func, :step)}
      end)
    else
      modified_step
    end
  end

  defp do_walk_inner_recipe(step, func) do
    if NestedStep.nested?(step) do
      update_inner_recipe(step, fn inner_recipe ->
        new_recipe = func.(inner_recipe)
        %{new_recipe | steps: walk(new_recipe.steps, func, :inner_recipe)}
      end)
    else
      step
    end
  end

  defp update_inner_recipe(step, updater) do
    {impl, in_k, out_k, opts} = Step.ensure_full_step(step)

    case Keyword.get(opts, :recipe) do
      %Recipe{} = r ->
        {impl, in_k, out_k, Keyword.put(opts, :recipe, updater.(r))}

      _ ->
        step
    end
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
