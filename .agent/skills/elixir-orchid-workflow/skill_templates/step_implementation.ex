# Template: Basic Module Step
defmodule MyApp.Steps.MyStep do
  use Orchid.Step
  require Logger
  alias Orchid.Param

  @doc """
  Single-input, single-output step.

  Input: Param with name :input_data
  Output: Param with name :output_data
  """
  @impl true
  def run(%Param{} = input, opts) do
    Logger.info("MyStep started", step: __MODULE__)

    # 1. Extract payload
    payload = Param.get_payload(input)

    # 2. Process
    result = process(payload, opts)

    # 3. Wrap in Param
    output = Param.new(:output_data, :my_type, result)

    {:ok, output}
  end

  @impl true
  def validate_options(opts) do
    case Keyword.fetch(opts, :timeout) do
      {:ok, timeout} when is_integer(timeout) and timeout > 0 -> :ok
      {:ok, _} -> {:error, ":timeout must be positive integer"}
      :error -> {:error, ":timeout required"}
    end
  end

  # ------- Private -------

  # Actually, this private function not essential
  defp process(payload, opts) do
    timeout = Keyword.get(opts, :timeout)
    # Your logic here
    payload
  end
end

# ============================================
# Template: Multi-input Step
# ============================================

defmodule MyApp.Steps.CombineStep do
  use Orchid.Step
  alias Orchid.Param

  @doc """
  Multi-input (list) step.

  Input: [:data_a, :data_b] → receives [Param, Param]
  Output: :merged
  """
  @impl true
  def run([%Param{} = param_a, %Param{} = param_b], _opts) do
    payload_a = Param.get_payload(param_a)
    payload_b = Param.get_payload(param_b)

    merged = merge(payload_a, payload_b)

    {:ok, Param.new(:merged, :combined, merged)}
  end

  defp merge(a, b), do: {a, b}
end

# ============================================
# Template: Function Step
# ============================================

defmodule MyApp.Steps.FunctionSteps do
  def my_step_func(input, opts) do
    # input is Param or [Param] or {Param, Param}
    # opts is keyword

    result = process(input)
    {:ok, Orchid.Param.new(:result, :type, result)}
  end

  # Anomynous function is also allowed
  def my_new_step_func(), do: fn input, _opts -> {:ok, Orchid.Param.new(:result, :type, process(input))} end

  defp process(%Orchid.Param{payload: payload}) do
    # Do some process
    payload
  end
end
