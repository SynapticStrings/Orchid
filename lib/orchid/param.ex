defmodule Orchid.Param do
  @moduledoc """
  The standard unit of data exchange.

  Every step receives and returns Param structs (or lists/tuples of them).
  It carries the payload and metadata.

  The purpose of this module is to abstract parameter handling and define a consistent
  interface for data exchange. This standardization allows developers using `Orchid`
  to focus on their business logic rather than the details of data flow management.
  """

  @type t :: %__MODULE__{
          name: name(),
          type: param_type(),
          payload: payload(),
          metadata: map()
        }
  defstruct [
    :name,
    :type,
    :payload,
    metadata: %{}
  ]

  ## Types

  @type name :: term()
  @type param_type :: atom() | module()
  @type ref_payload :: {:ref, module() | pid(), term()}
  @type raw_payload :: any() | nil
  @type payload :: raw_payload() | ref_payload()

  ## API

  @spec new(name(), param_type(), payload(), %{}) :: t()
  def new(name, type, payload \\ nil, metadata \\ %{}) do
    %__MODULE__{
      name: name,
      type: type,
      payload: payload,
      metadata: metadata
    }
  end

  @spec get_payload(t()) :: payload()
  def get_payload(%__MODULE__{payload: payload}), do: payload

  @spec set_payload(t(), payload()) :: t()
  def set_payload(%__MODULE__{} = param, new_payload),
    do: %__MODULE__{param | payload: new_payload}
end
