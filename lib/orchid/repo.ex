defmodule Orchid.Repo do
  @moduledoc """
  定义数据仓库的行为。
  用于存储不适合在 Param 中直接传递的大容量数据（如音频波形、模型权重）。

  暂时不考虑在 Orchid 中实现，但是其他应用可能会实现这个协议并且通过自定义 hook 调用。
  """

  @type key :: term()
  @type value :: term()
  @type opts :: keyword()

  @callback put(value(), opts()) :: {:ok, key()} | {:error, term()}

  @callback get(key()) :: {:ok, value()} | {:error, term()}

  @callback delete(key()) :: :ok | {:error, term()}
end
