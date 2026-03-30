defmodule Orchid.RepoTest do
  use ExUnit.Case

  defmodule MockRepo do
    @behaviour Orchid.Repo

    # use Agent

    # def init(_init_args), do: %{}

    # def put(old, key, value), do: Map.put(old, key, value)

    # def get(repo, key), do: Map.get(repo, key, :miss)
  end

  # setup block

  test "dispatch_store/3", _repo do
    # ...
  end
end