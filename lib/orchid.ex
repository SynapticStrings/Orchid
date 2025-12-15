defmodule Orchid do
  @moduledoc """
  The core entry point for the Orchid workflow engine.

  This module provides the primary interface (`run/3`) to execute defined Recipes.
  It is designed to be a flexible and extensible framework for task orchestration.
  """

  @facade_pass_through_keys [:global_hooks_stack, :executor_and_opts]
  @stack_keys [:global_hooks_stack, :operons_stack]

  @doc """
  Executes a workflow Recipe.

  It initializes the pipeline, injects any configured middleware (Operons), and
  starts the execution process.

  ### Options

  * `:return_response` - (boolean) If `true`, returns the full `Orchid.Operon.Response` struct
    (which includes assigns and metadata) instead of just the result payload. Defaults to `false`.
  * `:operons_stack` - (list) A list of additional middleware modules (Recipe-level hooks)
    to run before the execution phase. They are executed in the order provided.
  * `:global_hooks_stack` - (list)
  * `:executor_and_opts` - (tuple) Executor module and its options.

  ### Examples

      # Normal execution returning {:ok, results}
      Orchid.run(my_recipe, initial_params)

      # Execution returning the full Response struct
      Orchid.run(my_recipe, initial_params, return_response: true)
  """
  @spec run(Orchid.Recipe.t(), Orchid.Scheduler.initial_params(), keyword()) ::
          Orchid.Operon.Response.payload() | Orchid.Operon.Response.t()
  def run(recipe, input_params, opts \\ []) do
    response? = Keyword.get(opts, :return_response, false)
    operons_stack = Keyword.get(opts, :operons_stack, [])
    executor_and_opts = Keyword.get(opts, :executor_and_opts, {Orchid.Executor.Async, []})

    response =
      Orchid.Pipeline.run(
        operons_stack ++ [Orchid.Operon.Execute],
        %Orchid.Operon.Request{
          recipe: inject_opts_into_recipe(recipe, opts),
          inital_params: input_params,
          executor_and_opts: executor_and_opts
        }
      )

    if response? do
      response
    else
      response.payload
    end
  end

  def inject_opts_into_recipe(recipe, run_opts) do
    opts_to_inject = Keyword.take(run_opts, @facade_pass_through_keys)

    merged_opts =
      Keyword.merge(opts_to_inject, recipe.opts, fn key, parent_val, child_val ->
        if key in @stack_keys do
          # (run_opts) ++ (recipe)
          parent_val ++ child_val
        else
          # default: child_val
          child_val
        end
      end)

    %{recipe | opts: merged_opts}
  end

  def install_plugins(recipe, opts, plugins) do
    Enum.reduce_while(plugins, {recipe, opts}, fn {plug_mod, plug_conf}, {r, o} = acc ->
      case plug_mod.install(r, Keyword.merge(o, plugin_config: plug_conf)) do
        {:ok, res} -> {:count, res}
        {:error, reason} -> {:halt, {:error, {plug_mod, reason, acc}}}
      end
    end)
  end
end
