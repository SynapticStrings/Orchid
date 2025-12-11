# Gemini 给出的例子，没有涉及到时间序列
# 但是可以用容量来代替
alias Orchid.Param

defmodule MyKitchen do

  # 1. 定义磨豆步骤 (输入: :beans -> 输出: :powder)
  def grind(_opts) do
    fn inputs, _opts ->
        podwer_size = length(inputs.payload) * 3
        IO.puts("⚙️  正在磨豆...")
        podwer = for _ <- 1..podwer_size, do: "香喷喷的粉"
        {:ok, Param.new(:powder, :string, podwer)}
      end
  end

  # 2. 定义萃取步骤 (输入: {:powder, :water} -> 输出: :coffee_liquid)
  def brew(_opts) do
    fn [_powder, _water], _opts ->
        IO.puts("💧 正在萃取...")
        {:ok, Param.new(:coffee_liquid, :string, "热咖啡液")}
      end
  end

  # 3. 定义加糖步骤 (输入: {:coffee_liquid, :sugar} -> 输出: :sweet_coffee)
  def add_sugar(_opts) do
    fn _inputs, _opts ->
        IO.puts("🍬 正在加糖...")
        {:ok, Param.new(:sweet_coffee, :string, "好喝的加糖咖啡")}
      end
  end

  def to_guests(guest_name) do
    fn _inputs, _opts ->
        guest_name = guest_name || "客人"
        IO.puts("☕️ 递给 #{guest_name} 一杯咖啡，享受吧！")
        {:ok, Param.new(:served_coffee, :string, "递给 #{guest_name} 的咖啡")}
      end
  end
end

# --- 模拟框架运行 ---

# 1. 初始食材 (我们手里只有这些)
beans = for _ <- 1..5, do: "优质咖啡豆"
water = for _ <- 1..500, do: "纯净水"
sugar = for _ <- 1..20, do: "白砂糖"

initial_params = %{
  beans: Param.new(:beans, :string, beans),
  water: Param.new(:water, :string, water),
  sugar: Param.new(:sugar, :string, sugar)
}

# 2. 定义 Recipe (注意：顺序是完全乱的！)
# 格式: {实现, 输入key, 输出key}
steps = [
  # 这一步本来应该是最后做的，但我写在了第一个
  {MyKitchen.add_sugar([]), [:coffee_liquid, :sugar], :sweet_coffee},

  # 这一步是中间的
  {MyKitchen.brew([]), {:powder, :water}, :coffee_liquid},

  # 这一步才是最开始的
  {MyKitchen.grind([]), :beans, :powder},

  # 再加了一步递给客人
  {MyKitchen.to_guests([]), :sweet_coffee, :served_coffee}
]

for guest <- ["Alice", "Bob", "Peter"] do
  # 3. 执行 Recipe
  {:ok, res} = steps ++ [{MyKitchen.to_guests([guest]), :sweet_coffee, :served_coffee}]
  |> Orchid.Recipe.new(name: guest)
  |> Orchid.run(initial_params)
  # 4. 输出结果
  # |> IO.inspect(label: "Context New Example")

  res[:served_coffee] |> IO.inspect(label: "Coffee")

  IO.puts("🎉 #{guest} 收到了一杯美味的咖啡！")
end
