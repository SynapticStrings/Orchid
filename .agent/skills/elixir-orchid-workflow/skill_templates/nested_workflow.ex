# Template: Nested Workflow
defmodule MyApp.Recipes.Nested do
  alias Orchid.{Recipe, Param, Step}

  @doc "Sub-recipe for data cleaning"
  def cleaning_recipe do
    Recipe.new([
      {MyApp.Steps.RemoveNulls, :dirty_data, :no_nulls},
      {MyApp.Steps.RemoveDupes, :no_nulls, :unique},
      {MyApp.Steps.Normalize, :unique, :clean_data}
    ], name: :cleaning)
  end

  @doc "Sub-recipe for enrichment"
  def enrichment_recipe do
    Recipe.new([
      {MyApp.Steps.FetchMetadata, :id, :metadata},
      {MyApp.Steps.Merge, [:clean_data, :metadata], :enriched}
    ], name: :enrichment)
  end

  @doc "Parent recipe composing nested workflows"
  def full_pipeline do
    Recipe.new([
      # Fetch raw data
      {MyApp.Steps.FetchData, :source, :raw},

      # Nested: cleaning pipeline
      {Orchid.Step.NestedStep, :raw, :clean,
        [
          recipe: cleaning_recipe(),
          # Map parent's :raw to sub's :dirty_data
          input_map: %{raw: :dirty_data},
          # Map sub's :clean_data back to parent's :clean
          output_map: %{clean_data: :clean}
        ]},

      # Nested: enrichment pipeline
      {Orchid.Step.NestedStep, [:clean, :source], :final,
        [
          recipe: enrichment_recipe(),
          input_map: %{
            clean: :clean_data,   # Parent :clean → Sub :clean_data
            source: :id           # Parent :source → Sub :id
          },
          output_map: %{enriched: :final}
        ]},

      # Persist
      {MyApp.Steps.Save, :final, :saved}
    ], name: :full_pipeline)
  end

  @doc "Run with context propagation"
  def run_full(source) do
    recipe = full_pipeline()
    initial = [Param.new(:source, :id, source)]

    Orchid.run(recipe, initial,
      baggage: %{request_id: UUID.uuid4(), user_id: 42}
    )
  end

  # ========================================
  # Template: Custom Nested Step
  # ========================================

  defmodule CustomNested do
    use Orchid.Step
    @orchid_step_nested true

    @doc "Nested step with custom pre/post logic"
    def run(input, opts) do
      inner_recipe = Keyword.fetch!(opts, :recipe)

      # Pre-processing
      processed_input = preprocess(input)

      # Run inner recipe
      case Orchid.run_with_ctx(
        inner_recipe,
        [processed_input],
        Orchid.Runner.Hooks.Core.extract_workflow_ctx(opts)
      ) do
        {:ok, results} ->
          # Post-processing
          final = postprocess(results)
          {:ok, final}

        {:error, reason} ->
          {:error, {:nested_failed, reason}}
      end
    end

    defp preprocess(input), do: input
    defp postprocess(results), do: Map.values(results)
  end
end
