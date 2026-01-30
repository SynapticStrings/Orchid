#!/usr/bin/env elixir
# Usage: elixir validate_recipe.exs

defmodule RecipeValidator do
  alias Orchid.{Recipe, Param, Step}

  def validate_with_report(recipe, initial_params) do
    IO.puts("\n" <> String.duplicate("=", 60))
    IO.puts("RECIPE VALIDATION REPORT")
    IO.puts(String.duplicate("=", 60) <> "\n")

    # 1. Check structure
    IO.puts("📋 RECIPE INFO")
    IO.puts("  Name: #{recipe.name}")
    IO.puts("  Steps: #{length(recipe.steps)}")
    IO.puts("  Initial Params: #{length(initial_params)}")

    initial_keys = Enum.map(initial_params, &Map.get(&1, :name))
    IO.puts("  Initial Keys: #{inspect(initial_keys)}\n")

    # 2. Validate steps
    IO.puts("🔍 VALIDATING STEPS")

    case Recipe.validate_steps(recipe.steps, initial_keys) do
      :ok ->
        IO.puts("  ✅ All steps valid (no missing inputs, no cycles)\n")

      {:error, {:missing_inputs, missing_map}} ->
        IO.puts("  ❌ MISSING INPUTS:")

        Enum.each(missing_map, fn {idx, keys} ->
          {impl, _, _} = Step.extract_schema(Enum.at(recipe.steps, idx))
          IO.puts("    Step[#{idx}] (#{impl}): missing #{inspect(keys)}")
        end)

        IO.puts("")

      {:error, {:cyclic, cyclic_steps}} ->
        IO.puts("  ❌ CYCLIC DEPENDENCIES:")

        Enum.each(cyclic_steps, fn step ->
          {impl, in_k, out_k} = Step.extract_schema(step)
          IO.puts("    #{impl}: #{inspect(in_k)} → #{inspect(out_k)}")
        end)

        IO.puts("")

      {:error, other} ->
        IO.puts("  ❌ ERROR: #{inspect(other)}\n")
    end

    # 3. Check options
    IO.puts("⚙️  VALIDATING OPTIONS")

    Enum.each(recipe.steps, fn step ->
      {impl, _, _, opts} = Step.ensure_full_step(step)

      if Code.ensure_loaded?(impl) and function_exported?(impl, :validate_options, 1) do
        case impl.validate_options(opts) do
          :ok -> IO.puts("  ✅ #{impl}")
          {:ok, _} -> IO.puts("  ✅ #{impl}")
          {:error, reason} -> IO.puts("  ❌ #{impl}: #{inspect(reason)}")
        end
      else
        IO.puts("  ⚠️  #{impl}: no validate_options/1")
      end
    end)

    IO.puts("")

    # 4. Dependency graph
    IO.puts("📊 DEPENDENCY GRAPH")

    Enum.each(recipe.steps, fn {step, idx} ->
      {impl, in_k, out_k} = Step.extract_schema(step)
      in_list = in_k |> List.wrap() |> Enum.flat_map(&to_list/1)
      out_list = out_k |> List.wrap() |> Enum.flat_map(&to_list/1)

      IO.puts("  [#{idx}] #{impl}")
      IO.puts("       IN:  #{inspect(in_list)}")
      IO.puts("       OUT: #{inspect(out_list)}")
    end)

    IO.puts("\n" <> String.duplicate("=", 60) <> "\n")
  end

  defp to_list(atom) when is_atom(atom), do: [atom]
  defp to_list(list) when is_list(list), do: list
  defp to_list(tuple) when is_tuple(tuple), do: Tuple.to_list(tuple)
end

# Example usage (if run directly):
if System.argv() != [] do
  IO.puts("Recipe Validator - provide a recipe to validate")
else
  # Quick test
  IO.puts("Run with a recipe: elixir validate_recipe.exs")
end
