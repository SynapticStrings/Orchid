defmodule Orchid.Plugin do
  @moduledoc "Plugin behavior for extending Orchid's capabilities."

  @doc """
  Receives the recipe and current runtime options, returns the modified versions.
  """
  @callback install(Orchid.Recipe.t(), opts :: keyword()) ::
              {:ok, {Orchid.Recipe.t(), opts :: keyword()}} | {:error, term()}
end
