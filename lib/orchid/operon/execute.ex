defmodule Orchid.Operon.Execute do
  @moduledoc "Execute recipe."

  @behaviour Orchid.Operon

  alias Orchid.{Scheduler, WorkflowCtx}
  alias Orchid.Operon.{Request, Response}

  @impl true
  def call(%Request{} = req, _) do
    {executor, executor_opts} =
      WorkflowCtx.get_config(req.workflow_ctx, :executor_and_opts, {Orchid.Executor.Async, []})

    # This may cause warn when use dialyzer, so I ignore it in `.dialyzer_ignore.exs`
    # But I don't known how to ignore it in ElixirLS.
    payload =
      case Scheduler.build(req.recipe, req.inital_params, req.workflow_ctx) do
        {:ok, ctx} ->
          apply(executor, :execute, [ctx, executor_opts])

        {:error, reason} ->
          {:error, %Orchid.Error{reason: reason, kind: :logic_or_exception}}
      end

    %Response{payload: payload, assigns: req.assigns}
  end
end
