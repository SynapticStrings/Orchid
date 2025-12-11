defmodule Orchid.Recipe do
  @moduledoc """
  Defines a processing workflow (Recipe).

  A `Recipe` is essentially a collection of `Orchid.Step`s that describes a
  Directed Acyclic Graph (DAG) of data processing.

  It holds the definition of *what* needs to be done, but not the execution state.

  ### Example

      steps = [
        {MySteps.Download, :url, :raw_html},
        {MySteps.Parse, :raw_html, :data}
      ]

      recipe = Orchid.Recipe.new(steps, name: :scraper_flow)

  ### Options

  * `:name` - The name of the recipe (atom).
  """

  alias Orchid.{Recipe, Step}
  alias Orchid.Step.NestedStep

  @type t :: %__MODULE__{
          steps: [Step.t()],
          name: atom() | nil,
          opts: keyword()
        }
  defstruct steps: [], name: nil, opts: []

  @doc """
  Creates a new Recipe.

  ## Arguments

  * `steps` - A list of `Orchid.Step` definitions.
  * `opts` - Keyword options (e.g., `name: :my_recipe`).
  """
  @spec new([Step.t()], keyword()) :: t()
  def new(steps, opts \\ []) do
    %__MODULE__{
      steps: steps,
      name: Keyword.get(opts, :name),
      opts: opts
    }
  end

  @doc """
  Statically validates the steps within a recipe.

  It performs the following checks:
  1. **Option Validation**: Calls `Step.validate_options/1` for each step.
  2. **Missing Inputs**: Checks if all steps have their required input keys satisfied (either by initial params or previous steps).
  3. **Cyclic Dependencies**: Checks if the graph contains any cycles.
  """
  @spec validate_steps([Step.t()], [atom()]) :: :ok | {:error, term()}
  def validate_steps(steps, initial_keys) do
    with [] <- get_step_errors(steps),
         :ok <- detect_missing_inputs(steps, initial_keys),
         :ok <- detect_cycles(steps, initial_keys) do
      :ok
    else
      {:error, {:missing_inputs, missing_map}} ->
        {:error, {:missing_inputs, missing_map}}

      {:error, {:cyclic, cyclic_indices}} ->
        {:error, {:cyclic, cyclic_indices}}

      validate_errors ->
        {:error, {:option_validation_failed, validate_errors}}
    end
  end

  defp detect_missing_inputs(steps, initial_keys) do
    Recipe.Graph.check_missing_initial(steps, initial_keys)
  end

  defp detect_cycles(steps, initial_keys) do
    Recipe.Graph.check_cycles(steps, initial_keys)
  end

  @spec get_step_errors([Step.t()]) :: [] | [term()]
  defp get_step_errors(steps) do
    steps
    |> Enum.with_index()
    |> Enum.reduce([], fn {step, idx}, acc ->
      {impl, _, _, opts} = Orchid.Step.ensure_full_step(step)

      # 检查模块是否导出了 validate/1
      if is_atom(impl) and Code.ensure_loaded?(impl) and
           function_exported?(impl, :validate_options, 1) do
        case impl.validate_options(opts) do
          :ok -> acc
          {:error, reason} -> [{:invalid_step_option, idx, impl, reason} | acc]
        end
      else
        acc
      end
    end)
  end

  @doc """
  Injects options into steps globally (supports deep traversal).

  This function allows you to modify the configuration of specific steps
  within a recipe, including steps inside nested recipes.

  ### Selectors

  The `selector` determines which steps will receive the `new_opts`:

  * `:all` - Matches every step.
  * `module` (atom) - Matches steps implemented by this specific module.
  * `function` (arity 2) - Matches steps implemented by this specific function reference.
  * `predicate function` (`fn step -> boolean()`) - A custom function that receives the step and returns `true` if it should be modified.
  """
  @spec assign_options(
          Orchid.Recipe.t(),
          Step.implementation() | (Step.t() -> boolean()),
          keyword() | %{}
        ) :: Orchid.Recipe.t()
  def assign_options(%__MODULE__{} = recipe, selector, new_opts) do
    %{
      recipe
      | steps:
          walk(recipe.steps, fn step ->
            step
            |> do_match(selector)
            |> if(do: Step.inject_options(Step.ensure_full_step(step), new_opts), else: step)
          end)
    }
  end

  @doc """
  Performs a deep traversal on a list of steps.

  This function applies `func` to every step in the tree. If a step is a `NestedStep`
  (contains an inner recipe), it recursively traverses the inner steps as well.

  It supports both standard step lists and indexed step lists (used by `Orchid.Scheduler`).

  ### Modes

  * `:step` (Default) - The `func` receives and modifies the **Step** definition.
  * `:inner_recipe` - The `func` receives and modifies the **Inner Recipe** struct of a nested step.
  """
  @spec walk(
          [Step.t()] | [{Step.t(), non_neg_integer()}],
          (Step.t() -> Step.t()) | (Recipe.t() -> Recipe.t()),
          :step | :inner_recipe
        ) :: [Step.t()]
  def walk(steps, func, mode \\ :step)

  def walk(steps, func, :step) do
    Enum.map(steps, fn
      {step, idx} -> {do_walk_step(step, func), idx}
      step -> do_walk_step(step, func)
    end)
  end

  def walk(steps, func, :inner_recipe) do
    Enum.map(steps, fn
      {step, idx} -> {do_walk_inner_recipe(step, func), idx}
      step -> do_walk_inner_recipe(step, func)
    end)
  end

  defp do_walk_step(step, func) do
    modified_step = func.(step)

    if NestedStep.nested?(modified_step) do
      update_inner_recipe(modified_step, fn inner_recipe ->
        %{inner_recipe | steps: walk(inner_recipe.steps, func, :step)}
      end)
    else
      modified_step
    end
  end

  defp do_walk_inner_recipe(step, func) do
    if NestedStep.nested?(step) do
      update_inner_recipe(step, fn inner_recipe ->
        new_recipe = func.(inner_recipe)
        %{new_recipe | steps: walk(new_recipe.steps, func, :inner_recipe)}
      end)
    else
      step
    end
  end

  defp update_inner_recipe(step, updater) do
    {impl, in_k, out_k, opts} = Step.ensure_full_step(step)

    case Keyword.get(opts, :recipe) do
      %Recipe{} = r ->
        {impl, in_k, out_k, Keyword.put(opts, :recipe, updater.(r))}

      _ ->
        step
    end
  end

  defp do_match(step, selector) when is_atom(selector) or is_function(selector, 2) do
    {impl, _in_k, _out_k, _current_opts} = Step.ensure_full_step(step)

    case selector do
      :all -> true
      # Match by implementation module or function ref
      ^impl -> true
      _ -> false
    end
  end

  defp do_match(step, selector) when is_function(selector, 1) do
    selector.(step)
  end
end
