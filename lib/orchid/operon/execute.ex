defmodule Orchid.Operon.Execute do
  @behaviour Orchid.Operon

  alias Orchid.Scheduler
  alias Orchid.Operon.{Request, Response}

  @impl true
  def call(%Request{} = req, _) do
    {executor, executor_opts} = req.executor_and_opts

    case Scheduler.build(req.recipe, req.inital_params) do
      {:ok, ctx} ->
        %Response{
          payload: executor.execute(ctx, executor_opts),
          assigns: req.assigns
        }

      err ->
        %Response{
          payload: err,
          assigns: req.assigns
        }
    end
  end
end
