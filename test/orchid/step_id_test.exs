defmodule Orchid.StepIdTest do
  use ExUnit.Case

  alias Orchid.Step.ID

  describe "finger_print/2" do
    test "when not headless?, return whole step" do
      assert {Foo, _, _} = ID.finger_print({Foo, :a, :b}, false)
    end
  end

  describe "same?/2" do
    test "allow same type" do
      assert ID.same?({Foo, :foo, :bar}, {Foo, :foo, :bar})
      assert !ID.same?({Foo, :foo, :bar}, {Foo, :foz, :bac})
    end

    test "difference implementation doesn't matter" do
      assert ID.same?({Foo, :foo, :bar}, {Bar, :foo, :bar})
    end

    test "also allow different type" do
      assert ID.same?({Foo, {:foo, :bar}, :a}, {Foo, [:foo, :bar], {:a}})
    end
  end

  describe "normalize_keys_to_set/1" do
    test "accept nil" do
      assert MapSet.new() == ID.normalize_keys_to_set(nil)
    end

    test "accept single atom as key" do
      assert MapSet.equal?(ID.normalize_keys_to_set(:foo), MapSet.new([:foo]))
    end

    test "also accept tuple" do
      assert MapSet.equal?(ID.normalize_keys_to_set({:foo, :bar}), MapSet.new([:bar, :foo]))
    end

    test "it is underlying MapSet" do
      assert MapSet.equal?(
               ID.normalize_keys_to_set(MapSet.new([:foo, :bar])),
               MapSet.new([:bar, :foo])
             )
    end
  end
end
