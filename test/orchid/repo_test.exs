defmodule Orchid.RepoTest do
  use ExUnit.Case

  import Orchid.Repo

  defmodule MockRepo do
    @behaviour Orchid.Repo

    use Agent

    def start(inst) do
      Agent.start_link(fn -> %{} end, name: inst)
    end

    def put(repo, key, value) do
      Agent.update(repo, &Map.put(&1, key, val))

      :ok
    end

    def get(repo, key) do
      Agent.get(repo, fn map ->
        case Map.fetch(map, key) do
          {:ok, val} -> {:ok, val}
          :error -> :miss
        end)
    end
  end

  test "dispatch_store/3" do
    repo = MockRepo.start(:mock_orchid_repo)

    :ok = dispatch_store({MockRepo, repo}, :put, ["Foo", :bar])

    assert {:ok, :bar} == dispatch_store({MockRepo, repo}, :get, ["Foo"])
  end
end