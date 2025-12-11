defmodule DummyOperon do
  @behaviour QyCore.Operon
  def call(req, next), do: next.(req)
end

defmodule ErrorOperon do
  @behaviour QyCore.Operon
  def call(_req, _next), do: %QyCore.Operon.Response{payload: {:error, :failed}}
end

defmodule QyCore.PipelineTest do
  use ExUnit.Case
  alias QyCore.{Pipeline, Operon, Recipe}

  test "runs operon stack" do
    operons = [DummyOperon, Operon.Execute]
    req = %Operon.Request{recipe: Recipe.new([]), inital_params: []}
    %Operon.Response{payload: {:ok, _}} = Pipeline.run(operons, req)
  end

  test "handles no sink" do
    {:error, :no_sink_middleware} = Pipeline.run([], %Operon.Request{})
  end

  test "propagates errors through stack" do
    operons = [ErrorOperon]
    req = %Operon.Request{recipe: Recipe.new([]), inital_params: []}
    %Operon.Response{payload: {:error, :failed}} = Pipeline.run(operons, req)
  end
end
