# 自定义 Executor

目前存在的 Executor 如 Flask 的开发服务器一样简陋，并且因为我想保持内核精简的设计思路，并没有在 `:orchid` 中实现复杂 Executor 的想法。

整个 Elixir 最大的魅力就是其结合了 Ruby 的语法以及在 Erlang/BEAM 的 Rumtime 上，如果不使用其优势实在是可惜。

## 实现 Executor

### Executor 行为

### 使用 Scheduler 的函数以及上下文

### 结合 Operon/Hooks

### 入口

只需要简单的：

```elixir
# 等我把修改 Executor 的参数写到 facade 上。
result = Orchid.run(recipe, [])
```

即可。
