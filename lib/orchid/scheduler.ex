defmodule Orchid.Scheduler do
  @moduledoc """
  调度器模块，负责管理和调度 Recipe 中的步骤执行顺序。
  """
  alias Orchid.Scheduler.Context
  alias Orchid.{Recipe, Param, Step}

  @type initial_params :: [Param.t()] | Context.param_map()

  @doc """
  初始化执行上下文。
  """
  @spec build(Recipe.t(), initial_params()) ::
          {:ok, Context.t()} | {:error, term()}
  def build(%Recipe{} = recipe, initial_params) do
    initial_map =
      case initial_params do
        # 照理说空列表是有问题的，但还是把问题抛给后面的 validate 处理
        [] ->
          %{}

        [_ | _] ->
          Map.new(initial_params, fn param ->
            {Map.get(param, :name), param}
          end)

        %{} ->
          initial_params
      end

    initial_keys = Map.keys(initial_map)

    case Recipe.validate_steps(recipe.steps, initial_keys) do
      :ok -> do_build(recipe, initial_map)
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_build(recipe, initial_map) do
    step_with_options = Enum.map(recipe.steps, &Step.ensure_full_step/1)

    context = %Context{
      recipe: recipe,
      pending_steps: Enum.with_index(step_with_options),
      running_steps: MapSet.new(),
      available_keys: MapSet.new(Map.keys(initial_map)),
      params: initial_map,
      history: []
    }

    {:ok, context}
  end

  @doc """
  核心调度函数：找出所有“原料已就绪”且“未执行”的步骤。
  """
  @spec next_ready_steps(Orchid.Scheduler.Context.t()) :: [{Step.t(), non_neg_integer()}]
  def next_ready_steps(%Context{} = ctx) do
    Enum.filter(ctx.pending_steps, fn {step, idx} ->
      # 看谁的 needed 是 available 的子集
      # 不考虑运行的
      dependencies_met?(step, ctx.available_keys) and
        not MapSet.member?(ctx.running_steps, idx)
    end)
  end

  @doc """
  标记那些开始运行的。
  """
  @spec mark_running(Orchid.Scheduler.Context.t(), Step.t() | [Step.t()]) ::
          Orchid.Scheduler.Context.t()
  def mark_running(%Context{} = ctx, step_indices) do
    new_running = MapSet.union(ctx.running_steps, MapSet.new(step_indices))
    %{ctx | running_steps: new_running}
  end

  @doc """
  当 Step 执行完后，将结果合并回 Context。
  """
  @spec merge_result(
          Context.t(),
          non_neg_integer(),
          [Param.t()] | Param.t()
        ) :: Context.t()
  def merge_result(%Context{} = ctx, step_idx, output_params) do
    new_pending = Enum.reject(ctx.pending_steps, fn {_, idx} -> idx == step_idx end)
    new_running = MapSet.delete(ctx.running_steps, step_idx)

    new_params_map =
      case output_params do
        p = %Param{} ->
          %{p.name => p}

        [_ | _] ->
          Map.new(output_params, fn %Param{name: n} = p -> {n, p} end)
      end

    merged_params = Map.merge(ctx.params, new_params_map)

    new_keys = Map.keys(new_params_map)
    updated_keys = MapSet.union(ctx.available_keys, MapSet.new(new_keys))

    %{
      ctx
      | pending_steps: new_pending,
        running_steps: new_running,
        params: merged_params,
        available_keys: updated_keys,
        history: ctx.history ++ [step_idx]
    }
  end

  @doc """
  批量更新配置（运行时）。

  用于外部服务挂掉重启后但还有若干 steps 的 options 使用了旧的 reference 的情况。
  """
  @spec inject_opts(
          Orchid.Scheduler.Context.t(),
          (Step.t() -> boolean()),
          keyword()
        ) ::
          Orchid.Scheduler.Context.t()
  def inject_opts(%Context{} = ctx, selector, new_opts) do
    %{
      ctx
      | pending_steps:
          Recipe.walk(ctx.pending_steps, fn step ->
            if(selector.(step),
              do: step |> Step.ensure_full_step() |> Step.inject_options(new_opts),
              else: step
            )
          end)
    }
  end

  @spec done?(Context.t()) :: boolean()
  def done?(%Context{pending_steps: []}), do: true
  def done?(%Context{}), do: false

  @spec get_results(Context.t()) :: [Param.t()]
  def get_results(%Context{params: params}), do: params

  @spec get_results(Context.t(), atom()) :: [Param.t()]
  def get_results(%Context{params: params}, key),
    do:
      Enum.map(params, fn {k, v} -> if k == key, do: v, else: nil end)
      |> Enum.reject(&is_nil/1)

  defp dependencies_met?(step, available_keys) do
    {_impl, in_keys, _out} = Orchid.Step.extract_schema(step)

    needed = Orchid.Recipe.Graph.normalize_keys_to_set(in_keys)

    MapSet.subset?(needed, available_keys)
  end
end
