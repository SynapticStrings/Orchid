defmodule Orchid.Step.NestedStep do
  @moduledoc """
  Encapsulates a complete Recipe as a standalone Step to implement nested operations.

  This allows you to treat a complex sub-workflow as a single atomic step within a
  parent workflow.

  ### Required Options

  * `:recipe` - The inner `Orchid.Recipe` struct to be executed.

  ### Optional Options

  * `:executor` - The executor module to run the sub-process (defaults to `Orchid.Executor.Serial`).
  * `:executor_opts` - Options passed to the sub-executor (e.g., concurrency settings).
  * `:input_map` - Parameter name mapping: `%{parent_name => child_name}`.
    Use this when the parent step input name differs from what the inner recipe expects.
  * `:output_map` - Result name mapping: `%{child_name => parent_name}`.
    Use this to rename the inner recipe's output back to what the parent workflow expects.

  The mapping direction follows the flow of data (Input: Parent -> Child; Output: Child -> Parent).

  ## Examples

      nested_step = {Orchid.Step.NestedStep,
        :parent_param, :parent_result_param,
        [
          recipe: inner_recipe,
          executor: Orchid.Executor.Async,
          # Maps parent's :parent_param to child's :child_input
          input_map: %{parent_param: :child_input},
          # Maps child's :child_output back to :parent_result_param
          output_map: %{child_output: :parent_result_param}
        ]
      }

  ### Custom Nested Steps

  If you need to define a custom step that behaves like a nested step (e.g., custom logic before/after the sub-recipe),
  you must place the inner recipe in the `:recipe` option and implement `nested?/0`:

      defmodule MyNested do
        use Orchid.Step

        # Tell the Scheduler to treat this as a nested step during traversals
        def nested?(), do: true

        def run(input, opts) do
          # ... custom logic ...
        end
      end
  """

  alias Orchid.Scheduler
  use Orchid.Step

  def nested?, do: true

  @spec run(Step.input(), Step.step_options()) ::
          {:error, {:nested_execution_failed, term()}} | {:ok, Step.output()}
  @spec run(Step.input(), Step.step_options()) ::
          {:error, {:nested_execution_failed, term()}} | {:ok, Step.output()}
  def run(input_params, opts) do
    inner_recipe = Keyword.fetch!(opts, :recipe)
    executor = Keyword.get(opts, :executor, Orchid.Executor.Serial)
    # Note: In the original code, this key might overlap.
    # Assuming intent is to pass separate opts or reuse context opts.
    executor_options = Keyword.get(opts, :executor_opts, [])
    input_map = Keyword.get(opts, :input_map, %{})
    output_map = Keyword.get(opts, :output_map, %{})

    # Rename parameters passed from the parent layer to the names required by the child layer
    child_initial_params =
      input_params
      |> List.wrap()
      |> Enum.map(fn param ->
        # If a mapping exists, rename it; otherwise, keep the original name
        new_name = Map.get(input_map, param.name, param.name)
        %{param | name: new_name}
      end)

    # Start the sub-process
    with {:ok, ctx} <- Scheduler.build(inner_recipe, child_initial_params),
         {:ok, inner_results} <- executor.execute(ctx, executor_options) do
      # inner_results is a map of %{name => Param}

      # Extract data required by the parent layer from child results based on output_map or default rules
      # The output_map key is the child name, value is the parent name

      final_outputs =
        if map_size(output_map) > 0 do
          # If a mapping is defined, extract only the specified ones
          Enum.map(output_map, fn {child_name, parent_name} ->
            case Map.fetch(inner_results, child_name) do
              {:ok, param} -> %{param | name: parent_name}
              :error -> raise "Nested Recipe missing expected output: #{child_name}"
            end
          end)
        else
          # If no mapping is defined, for safety, we simply return all child results.
          # The parent Executor will automatically discard unneeded ones based on the Step definition schema.
          Map.values(inner_results)
        end

      {:ok, final_outputs}
    else
      {:error, reason} ->
        {:error, {:nested_execution_failed, reason}}
    end
  end

  @doc false
  def nested?(step) do
    {impl, _, _, _} = Step.ensure_full_step(step)

    is_atom(impl) and function_exported?(impl, :nested?, 0) and impl.nested?()
  end
end
