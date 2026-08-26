defmodule Orchid.Runner.Hooks.Core do
  @behaviour Orchid.Runner.Hook

  alias Orchid.{Param, Repo, WorkflowCtx}

  defguardp is_single_key(key) when is_atom(key) or is_binary(key)

  @spec call(Orchid.Runner.Context.t(), Orchid.Runner.Hook.next_fn()) ::
          Orchid.Runner.Hook.hook_result()
  def call(ctx, _next) do
    # inject opts
    final_opts =
      Keyword.merge(ctx.step_opts, ctx.recipe_opts) |> inject_workflow_ctx(ctx.workflow_ctx)

    case run_step(ctx.step_implementation, maybe_resolve_inputs(ctx.inputs), final_opts) do
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

  @doc """
  Align Orchid's step output names.

  Used for some bypass hook.
  """
  def align_output_names(params, out_key) when is_map(params) and not is_struct(params) do
    target_keys =
      cond do
        is_tuple(out_key) -> Tuple.to_list(out_key)
        is_list(out_key) -> out_key
        true -> [out_key]
      end

    results =
      Enum.map(target_keys, fn key ->
        case Map.fetch(params, key) do
          {:ok, val} ->
            val

          :error ->
            raise ArgumentError,
                  "Step output missing key: #{inspect(key)}. Available: #{inspect(Map.keys(params))}"
        end
      end)

    if is_single_key(out_key), do: hd(results), else: results
  end

  def align_output_names(param, out_key) when is_tuple(param) and is_tuple(out_key),
    do: align_output_names(Tuple.to_list(param), Tuple.to_list(out_key))

  def align_output_names(param, out_key) when is_tuple(param),
    do: align_output_names(Tuple.to_list(param), out_key)

  def align_output_names(param, out_key) when is_tuple(out_key),
    do: align_output_names(param, Tuple.to_list(out_key))

  def align_output_names([%Param{} = param], [out_key]) when is_single_key(out_key),
    do: %{param | name: out_key}

  def align_output_names(%Param{} = param, [out_key]) when is_single_key(out_key),
    do: %{param | name: out_key}

  def align_output_names([%Param{} = param], out_key) when is_single_key(out_key),
    do: %{param | name: out_key}

  def align_output_names(%Param{} = param, out_key) when is_single_key(out_key),
    do: %{param | name: out_key}

  def align_output_names([%Param{} | _] = params, [out_key]) when is_single_key(out_key),
    do: do_align_output_names(params, out_key)

  def align_output_names([%Param{} | _] = params, out_key) when is_single_key(out_key),
    do: do_align_output_names(params, out_key)

  def align_output_names(params, out_keys) when is_list(params) and not is_tuple(out_keys),
    do: params |> Enum.zip_with(List.wrap(out_keys), fn param, key -> %{param | name: key} end)

  defp do_align_output_names([%Param{} | _] = params, out_key) when not is_tuple(out_key) do
    case Enum.find(params, fn p -> p.name == out_key end) do
      %Param{} = match ->
        match

      nil ->
        raise ArgumentError,
              "Ambiguous step output: Step returned multiple params #{inspect(Enum.map(params, & &1.name))} but only one output key #{inspect(out_key)} is defined, and no param matched that name."
    end
  end

  # Ref payloads (`{:ref, store_conf, key}` — e.g. dehydrated by
  # orchid_stratum's BypassHook) are resolved here, at the innermost
  # layer, so every step sees raw payloads whether or not it opted into
  # caching. A missing blob is a hard failure, matching the stratum
  # hook's own hydration contract.
  defp maybe_resolve_inputs(%Param{payload: {:ref, conf, key}} = input) do
    case Repo.dispatch_store(conf, :get, [key]) do
      {:ok, payload} -> %{input | payload: payload}
      :miss -> raise "Hydration failed! Blob #{inspect(key)} missing from #{inspect(conf)}"
    end
  end

  defp maybe_resolve_inputs(%Param{} = input), do: input

  defp maybe_resolve_inputs(params) when is_list(params),
    do: Enum.map(params, &maybe_resolve_inputs/1)

  defp maybe_resolve_inputs(params) when is_map(params),
    do: Map.new(params, fn {k, v} -> {k, maybe_resolve_inputs(v)} end)

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
