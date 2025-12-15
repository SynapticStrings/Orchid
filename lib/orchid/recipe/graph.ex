defmodule Orchid.Recipe.Graph do
  @moduledoc """
  Responsible for analysing the topological structure of Recipes,
  primarily conducting static checks.
  """

  alias Orchid.Step

  def check_missing_initial(steps, initial_keys) do
    indexed_steps = build_initial_steps(steps)

    all_produced_keys =
      Enum.reduce(indexed_steps, MapSet.new(initial_keys), fn s, acc ->
        MapSet.union(acc, s.provides)
      end)

    missing_inputs =
      Enum.reduce(indexed_steps, %{}, fn step, acc ->
        missing = MapSet.difference(step.needed, all_produced_keys)

        if MapSet.size(missing) > 0 do
          Map.put(acc, step.index, MapSet.to_list(missing))
        else
          acc
        end
      end)

    case map_size(missing_inputs) do
      0 -> :ok
      _ -> {:error, {:missing_inputs, missing_inputs}}
    end
  end

  def check_cycles(steps, available) do
    # The logic here is analogous to Kahn's algorithm
    # Whenever a node satisfying dependencies is found, it is removed from the list
    # and its output added to available
    # If the list is non-empty yet no runnable node is found, the remaining nodes form a cycle
    case run_simulation(build_initial_steps(steps), normalize_keys_to_set(available)) do
      [] ->
        :ok

      remaining_steps ->
        # next steps create cycle(or waiting for each other)
        cyclic_indices = Enum.map(remaining_steps, & &1.step)
        {:error, {:cyclic, cyclic_indices}}
    end
  end

  defp build_initial_steps(steps) do
    steps
    |> Enum.with_index()
    |> Enum.map(fn {step, idx} ->
      {_impl, in_k, out_k} = Step.extract_schema(step)

      %{
        index: idx,
        step: step,
        needed: normalize_keys_to_set(in_k),
        provides: normalize_keys_to_set(out_k)
      }
    end)
  end

  defp run_simulation([], _available), do: []

  defp run_simulation(pending, available) do
    {ready, not_ready} =
      Enum.split_with(pending, fn %{needed: needed} ->
        MapSet.subset?(needed, available)
      end)

    case ready do
      [] ->
        # no step's realy, deadlock
        pending

      _ ->
        newly_produced =
          ready
          |> Enum.map(& &1.provides)
          |> Enum.reduce(MapSet.new(), &MapSet.union/2)

        new_available = MapSet.union(available, newly_produced)
        run_simulation(not_ready, new_available)
    end
  end

  @doc """
  normalize step's io key into MapSet。
  """
  @spec normalize_keys_to_set(nil | atom() | list() | tuple() | MapSet.t()) :: MapSet.t()
  def normalize_keys_to_set(nil), do: MapSet.new()
  def normalize_keys_to_set(atom) when is_atom(atom), do: MapSet.new([atom])
  def normalize_keys_to_set(list) when is_list(list), do: MapSet.new(list)
  def normalize_keys_to_set(tuple) when is_tuple(tuple), do: MapSet.new(Tuple.to_list(tuple))
  def normalize_keys_to_set(mapset), do: mapset
end
