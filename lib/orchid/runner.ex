defmodule Orchid.Runner do
  @moduledoc "Run step."
  alias Orchid.{Step, WorkflowCtx}
  alias Orchid.Runner.Hooks

  defmodule Context do
    @moduledoc """
    Context for step execution.

    * `:step_implementation` - Step implementation module or function.
    * `:in_keys` - Input keys.
    * `:out_keys` - Output keys.
    * `:step_opts` - Step options.
    * `:inputs` - Prepared inputs.
    * `:recipe_opts` - Recipe options.
    * `:telemetry_meta` - Telemetry metadata.
    * `:workflow_ctx` - Workflow context.
    * `:assigns` - Assigns map.
    """
    @type t :: %{
            step_implementation: Orchid.Step.implementation(),
            in_keys: Orchid.Step.input_keys(),
            out_keys: Orchid.Step.output_keys(),
            step_opts: Orchid.Step.step_options(),
            inputs: [Orchid.Param.t()],
            recipe_opts: keyword(),
            telemetry_meta: map(),
            workflow_ctx: Orchid.WorkflowCtx.t(),
            assigns: map()
          }
    defstruct [
      :step_implementation,
      :in_keys,
      :out_keys,
      :step_opts,
      :inputs,
      :recipe_opts,
      :telemetry_meta,
      :workflow_ctx,
      :assigns
    ]
  end

  @spec run(
          Step.t(),
          Orchid.Scheduler.Context.param_map(),
          keyword(),
          WorkflowCtx.t(),
          map()
        ) :: Orchid.Runner.Hook.hook_result()
  def run(step, ctx_params, recipe_opts, workflow_ctx, initial_assigns \\ %{}) do
    {impl, in_keys, out_keys, step_opts} = step

    initial_ctx = %Context{
      step_implementation: impl,
      in_keys: in_keys,
      out_keys: out_keys,
      step_opts: step_opts,
      inputs: prepare_inputs(in_keys, ctx_params),
      recipe_opts: recipe_opts,
      telemetry_meta: %{impl: impl, in_keys: in_keys, out_keys: out_keys},
      workflow_ctx: workflow_ctx |> WorkflowCtx.add_depth(Step.ID.finger_print(step)),
      assigns: initial_assigns
    }

    hook_stack =
      [Hooks.Telemetry] ++
        WorkflowCtx.get_config(workflow_ctx, :global_hooks_stack, []) ++
        Keyword.get(step_opts, :extra_hooks_stack, []) ++
        [WorkflowCtx.get_config(workflow_ctx, :core_hook, Hooks.Core)]

    run_pipeline(hook_stack, initial_ctx)
  end

  defp run_pipeline([], _ctx), do: {:error, :no_executor_hook}
  defp run_pipeline([hook | rest], ctx), do: hook.call(ctx, &run_pipeline(rest, &1))

  defp prepare_inputs(keys, params) when is_list(keys),
    do: Enum.map(keys, &Map.fetch!(params, &1))

  defp prepare_inputs(keys, params) when is_tuple(keys),
    do: Enum.map(Tuple.to_list(keys), &Map.fetch!(params, &1))

  defp prepare_inputs(key, params) when is_map(params), do: Map.fetch!(params, key)
end

defmodule Orchid.Runner.Hook do
  @moduledoc """
  Behaviour for runner hooks.
  """

  # Used for some plugin
  @type special_result :: {:special, any()}

  @type orchid_core_result :: {:ok, Orchid.Step.output()} | {:error, term()}

  @type hook_result :: orchid_core_result() | special_result()

  @type next_fn :: (Orchid.Runner.Context.t() -> hook_result())

  @doc """
  Callback to execute the hook.
  """
  @callback call(ctx :: Orchid.Runner.Context.t(), next_fn()) :: hook_result()
end
