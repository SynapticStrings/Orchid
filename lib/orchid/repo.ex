defmodule Orchid.Repo do
  @moduledoc """
  Defines the behaviour of the data warehouse.
  Used to store large volumes of data unsuitable for direct transmission via
  Param (such as audio waveforms or model weights).

  Implementation within Orchid is not currently envisaged, though other applications
  may implement this protocol and invoke it via custom hooks.
  """

  @type key :: term()
  @type value :: term()
  @type opts :: keyword()

  @callback put(value(), opts()) :: {:ok, key()} | {:error, term()}

  @callback get(key()) :: {:ok, value()} | {:error, term()}

  @callback delete(key()) :: :ok | {:error, term()}
end
