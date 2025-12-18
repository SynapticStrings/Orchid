defmodule Orchid.Step do
  @moduledoc """
  Defines the behavior and specification for a workflow step.

  A `Step` is the atomic unit of work in Orchid. It is responsible for receiving
  data (wrapped in `Orchid.Param`), performing a specific task, and returning
  new data.

  ### Usage

  To define a step, `use Orchid.Step` and implement the `c:run/2` callback:

      defmodule MySteps.Upcase do
        use Orchid.Step
        alias Orchid.Param

        @impl true
        def run(input_param, _opts) do
          payload = Param.get_payload(input_param)

          result =
            Param.new(:result, :string)
            |> Param.set_payload(String.upcase(payload))

          {:ok, result}
        end
      end

  ### Input Pattern Matching

  The structure of the `input` argument in `c:run/2` depends on how you define
  the input keys in your Recipe:

  * **Single Key:** If input is `:my_data`, `run/2` receives a single `%Param{}`.
  * **List of Keys:** If input is `[:a, :b]`, `run/2` receives a list `[%Param{}, %Param{}]`.
  * **Tuple of Keys:** If input is `{:a, :b}`, `run/2` receives a tuple `{%Param{}, %Param{}}`.

  ### Step Options

  Options can be passed when defining the step in a recipe or injected dynamically.
  Reserved options include:

  * `:extra_hooks_stack` - A list of additional hooks to run for this specific step.
  * `:__reporter_ctx__` - A map contains telemetry meta used by `report/3` to send progress updates.
  """
  alias Orchid.Param

  @typedoc """
  The implementation of a step.

  * `module()`: A module that implements the `Orchid.Step` behavior.
  * `function()`: A function `fn input, opts -> {:ok, params} | {:error, term} end`.
  """
  @type implementation ::
          module()
          | function()
          | nil

  @type io_key :: atom() | [atom()] | tuple() | MapSet.t()
  @type input_keys :: io_key()
  @type output_keys :: io_key()
  @type input :: tuple() | Param.t() | [Param.t()]
  @type output :: tuple() | Param.t() | [Param.t()]

  @typedoc "Options passed to the step execution context."
  @type step_options :: keyword()

  @typedoc """
  The schema definition of a step within a recipe.
  Format: `{Implementation, InputKeys, OutputKeys}`.
  """
  @type step_schema :: {implementation(), input_keys(), output_keys()}

  @typedoc """
  A fully qualified step definition including options.
  Format: `{Implementation, InputKeys, OutputKeys, Options}`.
  """
  @type step_with_options :: {
          implementation(),
          input_keys(),
          output_keys(),
          step_options()
        }
  @type t :: step_schema() | step_with_options()

  ## module step's callbacks.

  @doc """
  Determines if this step contains an inner recipe (Nested Step).
  Defaults to `false`.
  """
  @callback nested?() :: boolean()

  @doc """
  Validates the options passed to the step before execution.

  This is useful for checking required configuration keys (e.g., API tokens, thresholds).
  Returns `:ok` if valid, or `{:error, reason}` otherwise.
  """
  @callback validate_options(step_options()) :: :ok | {:error, term()}

  @doc """
  Executes the step logic.

  ## Arguments
  * `input` - The input parameters. Structure depends on `input_keys` definition.
  * `opts` - The keyword list of options available to this step.

  ## Return Values
  * `{:ok, output}` - Execution succeeded. `output` must match the structure of `output_keys`.
  * `{:error, reason}` - Execution failed. The step (and potentially the workflow) halts.
  """
  @callback run(input(), step_options()) :: {:ok, output()} | {:error, term()}

  ## public API

  @doc """
  Injects or merges options into a step definition.

  Supports both 3-element tuple (Schema) and 4-element tuple (Full Step).
  """
  @spec inject_options(t(), keyword()) :: step_with_options()
  def inject_options(step, options)

  def inject_options({_, _, _} = step_schema, new_opts),
    do: step_schema |> ensure_full_step() |> inject_options(new_opts)

  def inject_options({impl, in_keys, out_keys, opts}, new_opts) when is_map(new_opts),
    do: {impl, in_keys, out_keys, new_opts |> Enum.map(& &1) |> Keyword.merge(opts)}

  def inject_options({impl, in_keys, out_keys, opts}, new_opts) when is_list(new_opts),
    do: {impl, in_keys, out_keys, Keyword.merge(opts, new_opts)}

  @doc """
  Extracts the basic schema `{Impl, Input, Output}` from a step definition.
  """
  @spec extract_schema(t()) :: step_schema()
  def extract_schema({impl, in_keys, out_keys}), do: {impl, in_keys, out_keys}
  def extract_schema({impl, in_keys, out_keys, _opts}), do: {impl, in_keys, out_keys}

  @doc """
  Normalizes a step structure into the full 4-element tuple format.

  If no options are present, an empty list is added.
  """
  @spec ensure_full_step(t()) :: step_with_options()
  def ensure_full_step({impl, in_k, out_k}), do: {impl, in_k, out_k, []}
  def ensure_full_step({impl, in_k, out_k, opts}), do: {impl, in_k, out_k, opts}

  defmacro __using__(_opts) do
    quote do
      @behaviour Orchid.Step
      alias Orchid.Step

      @impl true
      def nested?(), do: false

      @impl true
      def validate_options(_opts), do: :ok

      @doc """
      Reports progress or status to the executor.

      ## Example

          def run(input, opts) do
            report(opts, :processing, "Start heavy calculation...")
            # ...
            report(opts, :uploading, 50)
            {:ok, result}
          end
      """
      def report(opts, progress, payload \\ nil) do
        case Keyword.get(opts, :__reporter_ctx__) do
          meta when is_map(meta) ->
            :telemetry.execute(
              [:orchid, :step, :progress],
              %{progress: progress},
              Map.merge(meta, %{payload: payload})
            )

          _ ->
            :ok
        end
      end

      defoverridable nested?: 0, validate_options: 1
    end
  end
end
