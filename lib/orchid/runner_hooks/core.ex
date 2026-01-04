defmodule Orchid.Runner.Hooks.Core do
  @behaviour Orchid.Runner.Hook

  alias Orchid.{Param, WorkflowCtx}

  @spec call(Orchid.Runner.Context.t(), Orchid.Runner.Hook.next_fn()) ::
          Orchid.Runner.Hook.hook_result()
  def call(ctx, _next) do
    # inject opts
    final_opts =
      Keyword.merge(ctx.step_opts, ctx.recipe_opts) |> inject_workflow_ctx(ctx.workflow_ctx)

    case run_step(ctx.step_implementation, ctx.inputs, final_opts) do
      {:ok, raw_output} ->
        renamed = align_output_names(raw_output, ctx.out_keys)
        {:ok, renamed}

      other ->
        # include error and special
        other
    end
  end

  def get_workflow_ctx_key, do: :__orchid_workflow_ctx__

  def inject_workflow_ctx(opts, ctx), do: Keyword.put(opts, get_workflow_ctx_key(), ctx)

  @spec extract_workflow_ctx(keyword()) :: WorkflowCtx.t()
  def extract_workflow_ctx(opts),
    do: Keyword.get(opts, get_workflow_ctx_key(), WorkflowCtx.new())

  # include mono, list and tuple
  defp align_output_names(param, out_key) when is_tuple(param) and is_tuple(out_key),
    do: align_output_names(Tuple.to_list(param), Tuple.to_list(out_key))

  defp align_output_names(param, out_key) when is_tuple(param),
    do: align_output_names(Tuple.to_list(param), out_key)

  defp align_output_names(param, out_key) when is_tuple(out_key),
    do: align_output_names(param, Tuple.to_list(out_key))

  defp align_output_names(%Param{} = param, out_key) when is_atom(out_key),
    do: %{param | name: out_key}

  defp align_output_names(%Param{} = param, [out_key]) when is_atom(out_key),
    do: %{param | name: out_key}

  defp align_output_names([%Param{} = param], out_key) when not is_tuple(out_key),
    do: %{param | name: out_key}

  defp align_output_names(params, out_keys) when is_list(params) and not is_tuple(out_keys),
    do: params |> Enum.zip_with(List.wrap(out_keys), fn param, key -> %{param | name: key} end)

  defp run_step(impl, inputs, opts) when is_atom(impl),
    do:
      if(Code.ensure_loaded?(impl) and function_exported?(impl, :run, 2),
        do: apply(impl, :run, [inputs, opts]),
        else: {:error, {:invalid_step_implementation, impl}}
      )

  defp run_step(run_fun, inputs, opts) when is_function(run_fun, 2),
    do: apply(run_fun, [inputs, opts])

  defp run_step(maybe_impl, _, _), do: {:error, {:invalid_step_implementation, maybe_impl}}
end
