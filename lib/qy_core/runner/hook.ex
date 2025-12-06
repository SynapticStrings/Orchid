defmodule QyCore.Runner.Hook do
  @type context :: %{
          step_implementation: QyCore.Recipe.Step.implementation(),
          in_keys: QyCore.Recipe.Step.input_keys(),
          out_keys: QyCore.Recipe.Step.output_keys(),
          step_default_opts: QyCore.Recipe.Step.step_options(),
          inputs: [QyCore.Param.t()],
          recipe_opts: keyword(),
          telemetry_meta: %{},
          assigns: %{}
        }
  @type next_fn :: (context -> {:ok, QyCore.Recipe.Step.output()} | {:error, term()})

  @callback call(context, next_fn) :: {:ok, QyCore.Recipe.Step.output()} | {:error, term()}
end
