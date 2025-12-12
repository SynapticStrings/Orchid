alias Orchid.Param

defmodule MyKitchen do

  def grind(_opts) do
    fn inputs, _opts ->
        podwer_size = length(inputs.payload) * 1
        IO.puts("⚙️  正在磨豆...")
        podwer = for _ <- 1..podwer_size, do: "香喷喷的粉"
        {:ok, Param.new(:powder, :string, podwer)}
      end
  end

  def brew(_opts) do
    fn [_powder, _water], _opts ->
        IO.puts("💧 正在萃取...")
        {:ok, Param.new(:coffee_liquid, :string, "热咖啡液")}
      end
  end

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


beans = for _ <- 1..5, do: "优质咖啡豆"
water = for _ <- 1..500, do: "纯净水"
sugar = for _ <- 1..20, do: "白砂糖"

initial_params = %{
  beans: Param.new(:beans, :string, beans),
  water: Param.new(:water, :string, water),
  sugar: Param.new(:sugar, :string, sugar)
}

# Out-of-order steps
steps = [
  {MyKitchen.add_sugar([]), [:coffee_liquid, :sugar], :sweet_coffee},

  {MyKitchen.brew([]), {:powder, :water}, :coffee_liquid},

  {MyKitchen.grind([]), :beans, :powder},

  {MyKitchen.to_guests([]), :sweet_coffee, :served_coffee}
]

# It seems today that all you see / Is violence in movies and sex on TV ...
for guest <- ~w(Alan Brain Chris Peter Lois Stewie Meg Quagmire) do
  {:ok, res} = steps ++ [{MyKitchen.to_guests([guest]), :sweet_coffee, :served_coffee}]
  |> Orchid.Recipe.new(name: guest)
  |> Orchid.run(initial_params)

  res[:served_coffee] |> IO.inspect(label: "Coffee")

  IO.puts("🎉 #{guest} Received a cup of coffee!")
end
