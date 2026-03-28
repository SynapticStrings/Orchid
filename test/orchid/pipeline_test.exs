defmodule DummyOperon do
  @behaviour Orchid.Operon
  def call(req, next), do: next.(req)
end

defmodule ErrorOperon do
  @behaviour Orchid.Operon
  def call(_req, _next), do: %Orchid.Operon.Response{payload: {:error, :failed}}
end

defmodule Orchid.PipelineTest do
  use ExUnit.Case
  alias Orchid.{Pipeline, Operon, Recipe}

  test "runs operon stack" do
    operons = [DummyOperon, Operon.Execute]
    req = %Operon.Request{recipe: Recipe.new([]), initial_params: []}
    %Operon.Response{payload: {:ok, _}} = Pipeline.run(operons, req)
  end

  test "handles no sink" do
    %Orchid.Operon.Response{payload: {:error, %Orchid.Error{reason: :no_sink_middleware}}} =
      Pipeline.run([], %Operon.Request{})
  end

  test "propagates errors through stack" do
    operons = [ErrorOperon]
    req = %Operon.Request{recipe: Recipe.new([]), initial_params: []}
    %Operon.Response{payload: {:error, :failed}} = Pipeline.run(operons, req)
  end
end
