defmodule Orchid.Operon.Execute do
  @behaviour Orchid.Operon

  alias Orchid.Scheduler
  alias Orchid.Operon.{Request, Response}

  @impl true
  def call(%Request{} = req, _) do
    {executor, executor_opts} = req.executor_and_opts

    # This may cause warn when use dialyzer.
    # I tried several methods, didn't work.
    # So I ignore it in `.dialyzer_ignore.exs`
    # But I don't known how to ignore it in ElixirLS.
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
