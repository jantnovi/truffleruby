require_relative '../../spec_helper'

describe "Struct#dig_fetch" do
  before(:each) do
    @klass = Struct.new(:a)
    @instance = @klass.new(@klass.new({ b: [1, 2, 3] }))
  end

  it "returns the nested value specified by the sequence of keys" do
    @instance.dig_fetch(:a, :a).should == { b: [1, 2, 3] }
  end

  it "returns the nested value specified if the sequence includes an index" do
    @instance.dig_fetch(:a, :a, :b, 0).should == 1
  end

  it "returns nil if any intermediate step is nil" do
    -> { @instance.dig_fetch(:b, 0) }.should raise_error(KeyError)
  end

  it "raises a TypeError if any intermediate step does not respond to #dig_fetch" do
    instance = @klass.new(1)
    -> {
      instance.dig_fetch(:a, 3)
    }.should raise_error(TypeError)
  end

  it "raises an ArgumentError if no arguments provided" do
    -> { @instance.dig_fetch }.should raise_error(ArgumentError)
  end

  it "calls #dig_fetch on any intermediate step with the rest of the sequence as arguments" do
    obj = Object.new
    instance = @klass.new(obj)

    def obj.dig_fetch(*args)
      {dug: args}
    end

    instance.dig_fetch(:a, :bar, :baz).should == { dug: [:bar, :baz] }
  end
end
