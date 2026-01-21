defmodule Orchid.Scheduler do
  @moduledoc """
  Scheduler is responsible for managing and scheduling the execution order of steps in the Recipe.
  """
  alias Orchid.{WorkflowCtx, Recipe, Param, Step}

  defmodule Context do
    @moduledoc """
    The state machine for workflow execution.

    It tracks the progress of a Recipe, including which steps are pending, running,
    or completed, and holds the data (params) produced so far.

    ## Data Structure Decisions

    You might notice a mix of Lists and MapSets. This is intentional to balance
    **deterministic execution** with **scheduling efficiency**:

    * `:pending_steps` (List) - Kept as a list to preserve the **definition order**
        from the Recipe. When multiple steps are ready simultaneously, Orchid prefers
        to execute them in the order they were written. This ensures predictable behavior,
        especially for the `Serial` executor.
    * `:running_steps` (MapSet) - Used for **O(1) lookups**. The scheduler frequently
        checks `member?/2` inside loops; a MapSet prevents this from becoming a performance bottleneck.
    * `:available_keys` (MapSet) - Optimized for **Set Algebra**. Dependency resolution
        relies heavily on subset checks (`subset?/2`), which MapSets handle efficiently.
    * `:recipe` (Struct) - The Recipe being executed.
    * `:params` (Map) - A map of parameters available in the current context.
    * `:history` (List) - A list of tuples recording the execution history of steps, including their indices and output keys.
    * `:workflow_ctx` (Struct) - The `Orchid.WorkflowCtx` struct associated with the execution.
    * `:assigns` (Map) - A map for storing additional context-specific data.
    """
    alias Orchid.{Param, Step, Recipe, WorkflowCtx}

    @type param_map :: %{optional(atom()) => Param.t()}
    @type step_index :: non_neg_integer()
    @type t :: %__MODULE__{
            # --- Static Config ---
            recipe: Recipe.t(),
            workflow_ctx: WorkflowCtx.t(),

            # List: To maintain priority based on definition order.
            pending_steps: [{Step.t(), step_index()}],

            # MapSet: For fast subset checking (dependency resolution).
            available_keys: MapSet.t(Step.io_key()),

            # MapSet: For fast exclusion checks during scheduling loop.
            running_steps: MapSet.t(step_index()),

            # Map: For random access to data payloads.
            params: param_map(),

            # List: Append-only log of execution path.
            history: [{Step.t(), MapSet.t(Step.output_keys())}],
            assigns: %{any() => any()}
          }
    defstruct [
      :recipe,
      :workflow_ctx,
      :params,
      :pending_steps,
      :running_steps,
      :available_keys,
      :history,
      :assigns
    ]
  end

  @typedoc "Initial parameters can be a list of Params or a map of Params."
  @type initial_params :: [Param.t()] | Context.param_map()

  @doc "Initialize scheduler context."
  @spec build(Recipe.t() | [Step.t()], initial_params(), WorkflowCtx.t()) ::
          {:ok, Context.t()} | {:error, term()}
  def build(steps, initial_params, workflow_context) when is_list(steps) do
    build(Recipe.new(steps), initial_params, workflow_context)
  end

  # I don't know how to convince Dialyzer that this function can return `{:ok, context}`.
  def build(%Recipe{} = recipe, initial_params, workflow_context) do
    initial_map =
      case initial_params do
        # throw the problem to validate functions
        [] ->
          %{}

        [%Param{} | _] ->
          Map.new(initial_params, fn param ->
            {Map.get(param, :name), param}
          end)

        # Allow single param
        %Param{} = p ->
          %{p.name => p}

        %{} ->
          initial_params
      end

    case Recipe.validate_steps(recipe.steps, Map.keys(initial_map)) do
      :ok -> do_build(recipe, initial_map, workflow_context)
      {:error, reason} -> {:error, reason}
    end
  end

  defp do_build(recipe, initial_map, workflow_context),
    do:
      {:ok,
       %Context{
         recipe: recipe,
         pending_steps: recipe.steps |> Enum.map(&Step.ensure_full_step/1) |> Enum.with_index(),
         running_steps: MapSet.new(),
         available_keys: MapSet.new(Map.keys(initial_map)),
         params: initial_map,
         history: [],
         workflow_ctx: workflow_context
       }}

  @doc """
  Core scheduling function: Identify all the steps that are "inputs params ready" and "not executed".
  """
  @spec next_ready_steps(Context.t()) :: [{Step.t(), Context.step_index()}]
  def next_ready_steps(%Context{} = ctx) do
    Enum.filter(ctx.pending_steps, fn {step, idx} ->
      dependencies_met?(step, ctx.available_keys) and not MapSet.member?(ctx.running_steps, idx)
    end)
  end

  defp dependencies_met?({_impl, in_keys, _out, _opts}, available_keys) do
    in_keys
    |> Step.ID.normalize_keys_to_set()
    |> MapSet.subset?(available_keys)
  end

  # TODO: Use readable ID
  @doc "Mark those steps that have started running(or remove when failed)."
  @spec mark_running_steps(
          Context.t(),
          Context.step_index() | [Context.step_index()],
          mode :: :running | :reattempt
        ) ::
          Context.t()
  def mark_running_steps(ctx, step_indices, mode \\ :running)

  def mark_running_steps(%Context{} = ctx, step_indices, :running) do
    running_step = MapSet.union(ctx.running_steps, normalize_step_indices(step_indices))
    %{ctx | running_steps: running_step}
  end

  def mark_running_steps(%Context{} = ctx, step_indices, :reattempt) do
    running_step = MapSet.difference(ctx.running_steps, normalize_step_indices(step_indices))
    %{ctx | running_steps: running_step}
  end

  defp normalize_step_indices(step_indices),
    do: MapSet.new(List.wrap(step_indices))

  @doc "After the Step is executed, merge the result back into the Context."
  @spec merge_result(Context.t(), non_neg_integer(), [Param.t()] | Param.t()) :: Context.t()
  def merge_result(%Context{} = ctx, step_idx, output_params) do
    step_filter = fn {_, idx} -> idx == step_idx end

    new_params_map =
      case output_params do
        p = %Param{} ->
          %{p.name => p}

        [_ | _] ->
          Map.new(output_params, fn %Param{name: n} = p -> {n, p} end)
      end

    new_keys = Map.keys(new_params_map)

    new_item =
      ctx.pending_steps
      |> Enum.filter(step_filter)
      |> Enum.map(fn {step, _idx} -> {step, MapSet.new(new_keys)} end)

    %{
      ctx
      | pending_steps: Enum.reject(ctx.pending_steps, step_filter),
        running_steps: MapSet.delete(ctx.running_steps, step_idx),
        params: Map.merge(ctx.params, new_params_map),
        available_keys: MapSet.union(ctx.available_keys, MapSet.new(new_keys)),
        history: ctx.history ++ [new_item]
    }
  end

  @doc """
  Batch update configuration (at runtime).

  This is used in scenarios where after an external service crashes and re-assigned,
  but several steps' options still use the old references.
  """
  @spec inject_opts(Context.t(), (Step.t() -> boolean()), keyword()) :: Context.t()
  def inject_opts(%Context{} = ctx, selector, new_opts) do
    update_func = fn step ->
      if(selector.(step),
        do: step |> Step.ensure_full_step() |> Step.inject_options(new_opts),
        else: step
      )
    end

    %{ctx | pending_steps: Recipe.walk(ctx.pending_steps, update_func)}
  end

  @spec done?(Context.t()) :: boolean()
  def done?(%Context{pending_steps: []}), do: true
  def done?(%Context{}), do: false

  @spec get_results(Context.t()) :: Context.param_map()
  def get_results(%Context{params: params}), do: params
  def get_results(%Context{params: params}, key), do: Map.get(params, key)
end
