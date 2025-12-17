defmodule Orchid.TestHelpers.HookFactory do
  defmacro __using__(_opts) do
    quote do
      @behaviour Orchid.Runner.Hook

      @impl true
      def call(ctx, next_fn), do: next_fn.(ctx)
    end
  end
end
