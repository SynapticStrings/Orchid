defmodule Orchid.Repo do
  @moduledoc """
  Defines the behaviour of the data warehouse.
  Used to store large volumes of data unsuitable for direct transmission via
  Param (such as audio waveforms or model weights).

  Implementation within Orchid is not envisaged, though other applications
  may implement this protocol and invoke it via custom hooks/operons/plugins.
  """
  # Integrate OrchidStratum's design.

  @type store_ref :: term()
  @type key :: binary()
  @type value :: term()

  @callback put(store_ref(), key(), value()) :: :ok

  @callback get(store_ref(), key()) :: {:ok, value()} | :miss

  @callback delete(store_ref(), key()) :: :ok

  defmodule Blob do
    # Used for content-addressed storage

    @callback exists?(store :: Orchid.Repo.store_ref(), Orchid.Repo.key()) :: boolean()
  end

  defmodule GC do
    @callback garbage_collect(store :: Orchid.Repo.store_ref(), opts :: term()) :: :ok
  end

  defmodule Pickle do
    # Yeah, Python's pickle
    # How to ensure its safety?
    @type serialized :: term()

    # opts: delete content in storage when serialization done?
    @callback serialize(store :: Orchid.Repo.store_ref(), condition :: :whole | {:partial, condition :: term()}, opts :: keyword())
              :: {:ok, serialized()} | {:error, reason :: term()}

    # May required c:validate/1

    @callback deserialize(store :: Orchid.Repo.store_ref(), serialized()) :: :ok | {:error, reason :: term()}
  end

  # defmodule Native do
  #   # Implement some zero-copy feature with NIF
  #   # maybe...
  # end
end
