defmodule Orchid.Operon do
  defmodule Request do
    @type t :: %__MODULE__{
            recipe: Orchid.Recipe.t(),
            inital_params: [Orchid.Param.t()],
            assigns: map(),
            operon_options: keyword(),
            executor_and_opts: {module(), keyword()},
            workflow_ctx: Orchid.WorkflowCtx.t()
          }
    defstruct [
      :recipe,
      :inital_params,
      assigns: %{},
      operon_options: [],
      executor_and_opts: {Orchid.Executor.Async, []},
      workflow_ctx: Orchid.WorkflowCtx.new()
    ]
  end

  defmodule Response do
    @type payload :: Orchid.Executor.response()
    @type t :: %__MODULE__{payload: payload(), assigns: %{}}
    defstruct [:payload, assigns: %{}]
  end

  @callback call(request :: Request.t(), maybe_next_func :: (Request.t() -> Response.t())) :: Response.t()
end
