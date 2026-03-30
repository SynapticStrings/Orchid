defmodule Orchid.Repo do
  @moduledoc """
  Behaviour for pluggable key-value storage adapters.

  Provides the minimal contract shared by every store used in the Orchid
  ecosystem: write a value, read it back.  Domain-specific extensions
  (existence checks, deletion, garbage collection, bulk export) are
  defined as separate optional behaviours under `Orchid.Repo.*`.

  ## Store Reference

  Every callback receives an opaque `store_ref` as its first argument.
  The concrete type is determined by the adapter (an ETS tid, a map of
  connection options, a PID, etc.).  Callers obtain the reference from
  the adapter's own `init/1` or equivalent.

  ## Composition with Extension Behaviours

  Adapters declare the capabilities they support:

      defmodule MyApp.BlobStore do
        @behaviour Orchid.Repo
        @behaviour Orchid.Repo.ContentAddressable
        # implements get/2, put/3, exists?/2
      end

      defmodule MyApp.MetaStore do
        @behaviour Orchid.Repo
        @behaviour Orchid.Repo.Deletable
        @behaviour Orchid.Repo.GC
        # implements get/2, put/3, delete/2, garbage_collect/2
      end
  """

  @type store_ref :: term()
  @type key :: binary()
  @type value :: term()

  @doc "Persists `value` under `key`. Must be idempotent."
  @callback put(store :: store_ref(), key(), value()) :: :ok

  @doc """
  Retrieves the value associated with `key`.

  Returns `{:ok, value}` on a hit, or `:miss` if no entry exists.
  """
  @callback get(store :: store_ref(), key()) :: {:ok, value()} | :miss

  @doc """
  Resolves a {Module, instance} store configuration tuple and dispatches
  the given function call, prepending the instance as the first argument.
  """
  def dispatch_store({repo_mod, instance}, fun, args),
    do: apply(repo_mod, fun, [instance | args])

  # ── Optional extension behaviours ──────────────────────────────

  defmodule Deletable do
    @moduledoc """
    Optional behaviour for adapters that support point deletion.

    Content-addressable blob stores may intentionally omit this;
    meta/index stores typically implement it.
    """
    @callback delete(store :: Orchid.Repo.store_ref(), Orchid.Repo.key()) :: :ok
  end

  defmodule ContentAddressable do
    @moduledoc """
    Optional behaviour for adapters that can answer cheap existence
    queries without deserialising the stored value.

    Used by cache-hit verification in OrchidStratum's BypassHook.
    """
    @callback exists?(store :: Orchid.Repo.store_ref(), Orchid.Repo.key()) :: boolean()
  end

  defmodule GC do
    @moduledoc """
    Optional behaviour for adapters that support garbage collection
    (TTL expiry, LRU eviction, capacity-based pruning, etc.).
    """
    @callback garbage_collect(store :: Orchid.Repo.store_ref(), opts :: keyword()) :: :ok
  end

  defmodule Transferable do
    @moduledoc """
    Optional behaviour for bulk export / import of store contents.

    Safety note: adapters **must** implement `validate/1` and callers
    **must** call it before `import/2` when the serialized payload
    crosses a trust boundary.
    """
    @type serialized :: binary()
    @type scope :: :all | {:keys, [Orchid.Repo.key()]} | {:condition, term()}

    @callback export(store :: Orchid.Repo.store_ref(), scope(), opts :: keyword()) ::
                {:ok, serialized()} | {:error, term()}

    @callback import(store :: Orchid.Repo.store_ref(), serialized()) ::
                :ok | {:error, term()}

    @callback validate(serialized()) :: :ok | {:error, term()}
  end
end
