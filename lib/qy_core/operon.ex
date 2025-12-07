defmodule QyCore.Operon do
  defmodule Request do
    @type t :: %__MODULE__{
            recipe: QyCore.Recipe.t(),
            inital_param: [QyCore.Param.t()],
            assigns: %{},
            operon_options: keyword(),
            executor_and_opts: {module(), keyword()}
          }
    defstruct [
      :recipe,
      :inital_param,
      :assigns,
      :operon_options,
      executor_and_opts: {QyCore.Executor.Async, []}
    ]
  end

  defmodule Responce do
    @type t :: %__MODULE__{
      payload: {:ok, [QyCore.Param.t()]} | {:error, term()},
      assigns: %{}
    }
    defstruct [
      :payload,
      assigns: %{}
    ]
  end

  @callback call(Request.t(), maybe_next_func :: (Request.t() -> Responce.t())) :: Responce.t()
end
