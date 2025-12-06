defmodule QyCore.Recipe.Step do
  @moduledoc """
  定义配方步骤（Step）的行为规范和类型。

  ### Step options

  关于 step 的选项，除了用户自定义以及插件注入外，还包括了：

  * `:__report__`：源于本模块关于 `report/3` 的定义，便于主动汇报进度/状态
  * `:extra_middleware_stack`：中间件堆栈，源于`QyCore.Runner`
  """
  alias QyCore.Param

  @typedoc """
  目前包括三类实现：

  * 模块实现：直接指定一个模块名，要求该模块实现 `QyCore.Recipe.Step` 行为。
  * 单函数实现：指定一个函数，等同于只实现 `run/2` 回调。
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

  @type step_options :: keyword()

  @type step_schema :: {implementation(), input_keys(), output_keys()}
  @type step_with_options :: {
          implementation(),
          input_keys(),
          output_keys(),
          step_options()
        }
  @type t :: step_schema() | step_with_options()

  ## module step 实现的回调

  @callback run(input(), step_options()) :: {:ok, output()} | {:error, term()}

  @callback nested?() :: boolean()

  ## public API

  def inject_options({impl, in_keys, out_keys, opts}, new_opts) when is_map(new_opts) do
    merged_opts = new_opts |> Enum.map(& &1) |> Keyword.merge(opts)
    {impl, in_keys, out_keys, merged_opts}
  end

  def inject_options({impl, in_keys, out_keys, opts}, new_opts) when is_list(new_opts) do
    {impl, in_keys, out_keys, Keyword.merge(opts, new_opts)}
  end

  def extract_schema({impl, in_keys, out_keys}), do: {impl, in_keys, out_keys}
  def extract_schema({impl, in_keys, out_keys, _opts}), do: {impl, in_keys, out_keys}

  defmacro __using__(_opts) do
    quote do
      @behaviour QyCore.Recipe.Step
      alias QyCore.Recipe.Step

      @impl true
      def nested?(), do: false

      @doc """
      向 Executor 汇报状态，通过查找 opts 中的 :__reporter__ 闭包并调用它。
      """
      def report(opts, progress, payload \\ nil) do
        case Keyword.get(opts, :__reporter__) do
          reporter_fn when is_function(reporter_fn, 2) ->
            reporter_fn.(progress, payload)

          _ ->
            :ok
        end
      end

      defoverridable nested?: 0
    end
  end
end
