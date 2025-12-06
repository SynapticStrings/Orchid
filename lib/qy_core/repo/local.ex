defmodule QyCore.Repo.Local do
  @behaviour QyCore.Repo
  use GenServer

  # --- Client API ---

  def start_link(opts \\ []) do
    GenServer.start_link(__MODULE__, opts, name: __MODULE__)
  end

  @impl true
  def put(value, _opts \\ []) do
    # 生成唯一 Key (这里简单用 UUID 或 ref 模拟)
    key = make_ref()
    true = :ets.insert(__MODULE__, {key, value})
    {:ok, key}
  end

  @impl true
  def get(key) do
    case :ets.lookup(__MODULE__, key) do
      [{^key, value}] -> {:ok, value}
      [] -> {:error, :not_found}
    end
  end

  @impl true
  def delete(key) do
    :ets.delete(__MODULE__, key)
    :ok
  end

  # --- Server Callbacks ---

  @impl true
  def init(_opts) do
    # 创建一张公共读写的 ETS 表
    :ets.new(__MODULE__, [:set, :named_table, :public])
    {:ok, nil}
  end
end
