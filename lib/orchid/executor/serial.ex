defmodule Orchid.Executor.Serial do
  @moduledoc """
  Serial Executor, implementing the behaviour of `Orchid.Executor`.

  It executes the steps within a Recipe sequentially, performing only
  one step at a time and waiting for its completion before proceeding
  to the next step.
  """
  @behaviour Orchid.Executor
  alias Orchid.Scheduler

  @impl true
  def execute(ctx, _executor_opts \\ []), do: loop(ctx, ctx.recipe.opts)

  defp loop(ctx, opts) do
    case Orchid.Executor.execute_next_step(ctx) do
      {:done, final_ctx} ->
        {:ok, Scheduler.get_results(final_ctx)}

      {:stuck, stuck_ctx} ->
        {:error, %Orchid.Error{reason: :stuck, context: stuck_ctx, kind: :exception}}

      {:cont, new_ctx} ->
        loop(new_ctx, opts)

      error ->
        error
    end
  end
end
