defmodule Orchid.Operon do
  defmodule Request do
    @type t :: %__MODULE__{
            recipe: Orchid.Recipe.t(),
            initial_params: Orchid.Scheduler.initial_params(),
            assigns: map(),
            operon_options: keyword(),
            workflow_ctx: Orchid.WorkflowCtx.t()
          }
    defstruct [
      :recipe,
      :initial_params,
      assigns: %{},
      operon_options: [],
      workflow_ctx: Orchid.WorkflowCtx.new()
    ]
  end

  defmodule Response do
    @type payload :: Orchid.Executor.response()
    @type t :: %__MODULE__{payload: payload(), assigns: %{}}
    defstruct [:payload, assigns: %{}]
  end

  @callback call(request :: Request.t(), maybe_next_func :: (Request.t() -> Response.t())) ::
              Response.t()
end
