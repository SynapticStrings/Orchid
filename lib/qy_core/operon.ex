defmodule QyCore.Operon do
  defmodule Request do
    @type t :: %__MODULE__{
            recipe: QyCore.Recipe.t(),
            inital_params: [QyCore.Param.t()],
            assigns: %{},
            operon_options: keyword(),
            executor_and_opts: {module(), keyword()}
          }
    defstruct [
      :recipe,
      :inital_params,
      :assigns,
      :operon_options,
      executor_and_opts: {QyCore.Executor.Async, []}
    ]
  end

  defmodule Response do
    @type payload :: QyCore.Executor.response()
    @type t :: %__MODULE__{
            payload: payload(),
            assigns: %{}
          }
    defstruct [
      :payload,
      assigns: %{}
    ]
  end

  @callback call(Request.t(), maybe_next_func :: (Request.t() -> Response.t())) :: Response.t()
end
