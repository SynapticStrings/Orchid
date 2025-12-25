defmodule Orchid.Runner do
  @moduledoc """
  Run step.
  """

  defmodule Context do
    @type t :: %{
            step_implementation: Orchid.Step.implementation(),
            in_keys: Orchid.Step.input_keys(),
            out_keys: Orchid.Step.output_keys(),
            step_opts: Orchid.Step.step_options(),
            inputs: [Orchid.Param.t()],
            recipe_opts: keyword(),
            telemetry_meta: %{},
            workflow_ctx: Orchid.WorkflowCtx.t(),
            assigns: %{}
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
          Orchid.Step.t(),
          Orchid.Scheduler.Context.param_map(),
          keyword(),
          Orchid.WorkflowCtx.t(),
          map()
        ) :: {:ok, Orchid.Step.output()} | {:error, term()}
  def run(step, ctx_params, recipe_opts, workflow_ctx, initial_assigns \\ %{}) do
    {impl, in_keys, out_keys, step_opts} = Orchid.Step.ensure_full_step(step)

    initial_ctx = %Context{
      step_implementation: impl,
      in_keys: in_keys,
      out_keys: out_keys,
      step_opts: step_opts,
      inputs: prepare_inputs(in_keys, ctx_params),
      recipe_opts: recipe_opts,
      telemetry_meta: %{impl: impl, in_keys: in_keys, out_keys: out_keys},
      workflow_ctx: Orchid.WorkflowCtx.add_step(workflow_ctx, Orchid.Step.ID.finger_print(step)),
      assigns: initial_assigns
    }

    hook_stack =
      [Orchid.Runner.Hooks.Telemetry] ++
        Keyword.get(recipe_opts, :global_hooks_stack, []) ++
        Keyword.get(step_opts, :extra_hooks_stack, []) ++
        [Orchid.Runner.Hooks.Core]

    run_pipeline(hook_stack, initial_ctx)
  end

  defp run_pipeline([], _ctx), do: {:error, :no_executor_hook}
  defp run_pipeline([hook | rest], ctx), do: hook.call(ctx, &run_pipeline(rest, &1))

  defp prepare_inputs(keys, params) when is_list(keys),
    do: Enum.map(keys, &Map.fetch!(params, &1))

  defp prepare_inputs(keys, params) when is_tuple(keys),
    do: Enum.map(Tuple.to_list(keys), &Map.fetch!(params, &1))

  # Let it crash.
  defp prepare_inputs(key, params) when is_map(params), do: Map.fetch!(params, key)
end

defmodule Orchid.Runner.Hook do
  @type next_fn :: (Orchid.Runner.Context.t() -> {:ok, Orchid.Step.output()} | {:error, term()})

  @callback call(ctx :: Orchid.Runner.Context.t(), next_fn) ::
              {:ok, Orchid.Step.output()} | {:error, term()}
end
