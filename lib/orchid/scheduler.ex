defmodule Orchid.Scheduler do
  @moduledoc """
  Scheduler is responsible for managing and scheduling the execution order of steps in the Recipe.
  """
  alias Orchid.{Recipe, Param, Step}

  defmodule Context do
    alias Orchid.{Param, Step, Recipe}

    @type param_map :: %{optional(atom()) => Param.t()}
    @type step_index :: non_neg_integer()
    @type t :: %__MODULE__{
            recipe: Recipe.t(),
            pending_steps: [{Step.t(), step_index()}],
            available_keys: MapSet.t(Step.io_key()),
            params: param_map(),
            running_steps: MapSet.t(Step.t()),
            history: [{step_index(), param_map() | [Param.t()] | Param.t()}],
            assings: %{any() => any()}
          }
    defstruct [
      ## Origin Orchid
      # Recipe
      # Used for Executor, edit is not allowed for consistency
      :recipe,
      # steps where not executed
      :pending_steps,
      # keys we have
      :available_keys,
      # actual datas
      :params,
      # running steps
      :running_steps,
      # execution history
      :history,
      ## other context
      :assings
    ]
  end

  @type initial_params :: [Param.t()] | Context.param_map()

  @doc "Initialize scheduler context."
  @spec build(Recipe.t(), initial_params()) ::
          {:ok, Context.t()} | {:error, term()}
  # I don't know how to convince Dialyzer that this function can return `{:ok, context}`.
  def build(%Recipe{} = recipe, initial_params) do
    initial_map =
      case initial_params do
        # throw the problem to validate functions
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

  defp do_build(recipe, initial_map),
    do:
      {:ok,
       %Context{
         recipe: recipe,
         pending_steps: recipe.steps |> Enum.map(&Step.ensure_full_step/1) |> Enum.with_index(),
         running_steps: MapSet.new(),
         available_keys: MapSet.new(Map.keys(initial_map)),
         params: initial_map,
         history: []
       }}

  @doc """
  Core scheduling function: Identify all the steps that are "inputs params ready" and "not executed".
  """
  @spec next_ready_steps(Context.t()) :: [{Step.t(), Context.step_index()}]
  def next_ready_steps(%Context{} = ctx) do
    Enum.filter(ctx.pending_steps, fn {step, idx} ->
      # See whose needed is a subset of available
      # And exclude running
      dependencies_met?(step, ctx.available_keys) and
        not MapSet.member?(ctx.running_steps, idx)
    end)
  end

  defp dependencies_met?(step, available_keys) do
    {_impl, in_keys, _out} = Orchid.Step.extract_schema(step)

    needed = Orchid.Recipe.Graph.normalize_keys_to_set(in_keys)

    MapSet.subset?(needed, available_keys)
  end

  @doc "Mark those steps that have started running."
  @spec mark_running_steps(
          Context.t(),
          Context.step_index() | [Context.step_index()],
          mode :: :running | :reattempt
        ) ::
          Context.t()
  def mark_running_steps(ctx, step_indices, mode \\ :running)

  def mark_running_steps(%Context{} = ctx, step_indices, :running),
    do: %{
      ctx
      | running_steps: MapSet.union(ctx.running_steps, normalize_step_indices(step_indices))
    }

  # used when try to re-attempt a failed step.
  # remove from `running_steps` firstly.
  def mark_running_steps(%Context{} = ctx, step_indices, :reattempt),
    do: %{
      ctx
      | running_steps: MapSet.difference(ctx.running_steps, normalize_step_indices(step_indices))
    }

  defp normalize_step_indices(step_indices),
    do: MapSet.new(List.wrap(step_indices))

  @doc "After the Step is executed, merge the result back into the Context."
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
        history:
          ctx.history ++ [Enum.filter(ctx.pending_steps, fn {_, idx} -> idx == step_idx end)]
    }
  end

  @doc """
  Batch update configuration (at runtime).

  This is used in scenarios where after an external service crashes and re-assigned,
  but several steps' options still use the old references.
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
end
