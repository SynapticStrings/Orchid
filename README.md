# QyCore

QyCore 是一个基于 Elixir 的，灵感源于个人企划的工作流编排引擎。

主要用于需要对时间序列（或时间序列相关的序列）进行负责处理且对实时性要求不高的场景，提供一个用于后续开发的相关协议或接口。

## 职责

### 定义

#### `QyCore.Param`

#### `QyCore.Step`

#### `QyCore.Recipe`

### 调度

主要是 `QyCore.Scheduler` 模块负责。

### 执行行为与执行器

Recipe 层面的执行由 `QyCore.Executor` 行为负责。

目前 `qy_core` 包括两个执行器：

- `QyCore.Executor.Serial`
- `QyCore.Executor.Async`

Step 层面的执行由 `QyCore.Runner.run/3` 负责。

因为 Step 原子操作的性质，没有再作进一步的 behaviour-adapter 的设计，但考虑业务的复杂程度，引入了钩子机制。

### 分层钩子

#### Step 层面（Hook）

在负责运行 step 的 `QyCore.Runner` 中，数据如洋葱一般从外层经由内层再回到外层。

每个 hook 的大致流程如下：

```elixir
defmodule MyHook do
  @behaviour QyCore.Runner.Hook

  def call(ctx, next) do
    # Prelude
    ...

    # Execute inner part
    case next.(ctx) do
      # When success
      {:ok, result} ->
        ...

      # When failed
      {:error, term} ->
        ...
    end
  end
end
```

因此从宏观层面，Hooks 的顺序以及定义需要仔细考虑这点。

需要运行额外的 Hook ，需要在 step 的 `opts[:extra_hooks_stack]` 中予以配置。

目前 Runner 有两个 hooks：

- `QyCore.Runner.Hooks.Telemetry` 通信
- `QyCore.Runner.Hooks.Core` 执行 step

#### Recipe 层面（Pipeline & Operon）

和 hooks 类似，也是按照洋葱一般的数据流程处理。

起了个比较怪的名字——操纵子，可能后面会改。

负责运行的部分是 `QyCore.Pipeline` ，其调用一系列遵循 `QyCore.Operon` 协议的中间件。

但是不同的是，我们定义了两类结构体 `QyCore.Operon.Request` 以及 `QyCore.Operon.Responce` 。

负责转变的模块就是包装了 Executor 的 `QyCore.Opeon.Execute` 。

暂时还没有引入额外的中间件，但后面会增加。

### 运行时上下文传递

- Pipeline 层级
- Executor 层级
- Runner Hooks 层级
- Step 层级

### 遍历注入

#### step 的修改

#### recipe 的修改

## Roadmap

- [x] 声明式步骤
- [x] 流程编排
- [x] 嵌套 recipe
- [x] executor 协议与实现
- [x] 钩子
- [ ] 运行前修改
  - [x] step 配置（通过 `QyCore.Recipe.assign_options/3`）
  - [ ] recipe 层面的修改 step （注入、删除）
  - [ ] recipe 配置
  - [ ] operon 堆修改
  - [ ] hook 堆修改
- [ ] 运行前检查
  - [x] Recipe 缺失检查
  - [ ] Recipe 循环检查
  - [x] Step option 检查（step 层面）
- [ ] 运行时修改
  - *仅针对尚未运行的 steps*
  - [x] step 配置（`QyCore.Scheduler.update_pending_steps_options/3` ）
  - [ ] executor 配置
  - [ ] recipe 配置
  - [ ] runner hooks
- [ ] API 固化
  - [ ] 梳理逻辑
  - [ ] 编写文档
  - [ ] 100% coverage

## 安装

在 `mix.exs` 中添加：

```elixir
[
  {
    :qy_core,
    git: "https://github.com/SynapticStrings/QyCore.git",
    branch: "core"
  }
]
```
