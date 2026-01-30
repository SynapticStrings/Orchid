# Template: Basic Recipe with Validation
defmodule MyApp.Recipes do
  alias Orchid.{Recipe, Param, Runner}

  @doc "Defines a multi-stage data processing pipeline"
  def data_pipeline_recipe do
    steps = [
      # Fetch data from source
      {MyApp.Steps.Fetch, :source_id, :raw_data,
        [timeout: 5000]},

      # Parse into structured format
      {MyApp.Steps.Parse, :raw_data, :structured,
        [format: :json]},

      # Validate against schema
      {MyApp.Steps.Validate, :structured, :validated,
        [schema: MyApp.Schemas.DataSchema]},

      # Transform for consumption
      {MyApp.Steps.Transform, :validated, :final,
        [transform: :camel_case]}
    ]

    Recipe.new(steps, name: :data_pipeline)
  end

  @doc "Execute with validation"
  def run_pipeline(source_id) do
    recipe = data_pipeline_recipe()

    initial_params = [
      Param.new(:source_id, :id, source_id)
    ]

    # Orchid can validate automatically BEFORE execution
    initial_keys = Enum.map(initial_params, &Map.get(&1, :name))
    Orchid.run(recipe, initial_params,
      executor_and_opts: {Orchid.Executor.Async, [concurrency: 4]}
    )
  end

  # ========================================
  # Template: With Hooks
  # ========================================

  def pipeline_with_auth do
    recipe = data_pipeline_recipe()

    initial_params = [...]

    Orchid.run(recipe, initial_params,
      global_hooks_stack: [MyApp.Hooks.AuthCheck, MyApp.Hooks.Metrics],
      baggage: %{user_id: 123, request_id: "xyz"}
    )
  end

  # ========================================
  # Template: With Options Injection
  # ========================================

  def pipeline_with_dynamic_config(user_tier) do
    recipe = data_pipeline_recipe()

    # Inject options based on user tier
    recipe =
      case user_tier do
        :premium ->
          Recipe.assign_options(recipe, :all, timeout: 10000, retries: 3)

        :standard ->
          Recipe.assign_options(recipe, :all, timeout: 5000, retries: 1)

        :free ->
          Recipe.assign_options(recipe, :all, timeout: 2000, retries: 0)
      end

    Orchid.run(recipe, [...])
  end
end
