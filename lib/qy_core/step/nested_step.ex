defmodule QyCore.Step.NestedStep do
  @moduledoc """
  将一个完整的 Recipe 封装为一个独立的 Step 以实现嵌套操作。

  需要的选项:

  - :recipe -> 要运行的内部 Recipe 结构体
  - :executor (可选) -> 指定运行子流程的执行器模块 (默认 `QyCore.Executor.Serial`)
  - :input_map (可选) -> `%{parent_name => child_name}` 参数名映射（用于两级 step 名称不一样的情形）
  - :output_map (可选) -> `%{child_name => parent_name}` 结果名映射

  io mapper 的顺序可以理解为按照数据流的顺序进行。

  ## Examples

      nested_step = {QyCore.Step.NestedStep,
        :parent_param, :parent_result_param,
        [
          recipe: inner_recipe,  # Options for recipe wrote in here!!
          executor: QyCore.Executor.Async,
          input_map: %{parent_param: :child_input},
          output_map: %{child_output: :parent_result_param},
          ...
        ]
      }

  如果你需要自定义的具备嵌套功能的 step ，请将内部的 recipe 内容放到 `:recipe`
  参属下且如下设置：

      defmodule MyNested do
        use QyCore.Step

        def nested?(), do: true

        def run(..), do: ..
      end
  """

  use QyCore.Step

  def nested?, do: true

  @spec run(Step.input(), Step.step_options()) ::
          {:error, {:nested_execution_failed, term()}} | {:ok, Step.output()}
  def run(input_params, opts) do
    inner_recipe = Keyword.fetch!(opts, :recipe)
    executor = Keyword.get(opts, :executor, QyCore.Executor.Serial)
    input_map = Keyword.get(opts, :input_map, %{})
    output_map = Keyword.get(opts, :output_map, %{})

    # 将父层传进来的 Params 重命名为子层需要的名字
    child_initial_params =
      input_params
      |> List.wrap()
      |> Enum.map(fn param ->
        # 如果有映射就改名，没有就保持原名
        new_name = Map.get(input_map, param.name, param.name)
        %{param | name: new_name}
      end)

    # 启动子流程
    # 从这里可以看出来传入的是 recipe 结构体
    case executor.execute(inner_recipe, child_initial_params) do
      {:ok, inner_results} ->
        # inner_results 是 %{name => Param}

        # 根据 output_map 或默认规则，从子结果中提取父层需要的数据
        # 这里的 output_map key 是子层名字，value 是父层名字

        final_outputs =
          if map_size(output_map) > 0 do
            # 如果定义了映射，只提取映射中指定的
            Enum.map(output_map, fn {child_name, parent_name} ->
              case Map.fetch(inner_results, child_name) do
                {:ok, param} -> %{param | name: parent_name}
                :error -> raise "Nested Recipe missing expected output: #{child_name}"
              end
            end)
          else
            # 如果没定义映射，为了安全，我们应该只返回在 Step 定义中声明过的 output_keys
            # 但 step.run/2 无法直接知道自己的 output_keys 定义。
            # 所以这里我们简单地返回所有子结果（除了改名的），
            # 父级 Executor 会根据 Step 定义自动丢弃不需要的。
            Map.values(inner_results)
          end

        {:ok, final_outputs}

      {:error, reason} ->
        {:error, {:nested_execution_failed, reason}}
    end
  end

  def nested?(step) do
    {impl, _, _, _} = Step.ensure_full_step(step)

    is_atom(impl) and function_exported?(impl, :nested?, 0) and impl.nested?()
  end
end
