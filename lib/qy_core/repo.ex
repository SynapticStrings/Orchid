defmodule QyCore.Repo do
  @moduledoc """
  定义数据仓库的行为。
  用于存储不适合在 Param 中直接传递的大容量数据（如音频波形、模型权重）。
  """

  @type key :: term()
  @type value :: term()
  @type opts :: keyword()

  @callback put(value(), opts()) :: {:ok, key()} | {:error, term()}

  @callback get(key()) :: {:ok, value()} | {:error, term()}

  @callback delete(key()) :: :ok | {:error, term()}
end
