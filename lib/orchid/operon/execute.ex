defmodule Orchid.Operon.Execute do
  @behaviour Orchid.Operon

  alias Orchid.{Scheduler, WorkflowCtx}
  alias Orchid.Operon.{Request, Response}

  @impl true
  def call(%Request{} = req, _) do
    {executor, executor_opts} =
      WorkflowCtx.get_config(req.workflow_ctx, :executor_and_opts, {Orchid.Executor.Async, []})

    # This may cause warn when use dialyzer, so I ignore it in `.dialyzer_ignore.exs`
    # But I don't known how to ignore it in ElixirLS.
    case Scheduler.build(req.recipe, req.inital_params, req.workflow_ctx) do
      {:ok, ctx} ->
        %Response{
          payload: do_execute(executor, ctx, executor_opts),
          assigns: req.assigns
        }

      {:error, reason} ->
        %Response{
          payload: {:error, %Orchid.Error{reason: reason, kind: :logic_or_exception}},
          assigns: req.assigns
        }
    end
  end

  defp do_execute(executor, ctx, executor_opts),
    do: apply(executor, :execute, [ctx, executor_opts])
end
