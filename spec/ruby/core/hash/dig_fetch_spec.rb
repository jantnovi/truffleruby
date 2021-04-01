require_relative '../../spec_helper'
require_relative '../../shared/hash/key_error'
require 'pry'

describe "Hash#dig_fetch" do
  context "when the key is not found" do
    it_behaves_like :key_error, -> obj, key { obj.dig_fetch(key) }, {}
    it_behaves_like :key_error, -> obj, key { obj.dig_fetch(key) }, { a: 5 }
    it_behaves_like :key_error, -> obj, key { obj.dig_fetch(key) }, { :a => 5 }
    it_behaves_like :key_error, -> obj, key { obj.dig_fetch(key, key) }, { a: { :b => 5 } }
    it_behaves_like :key_error, -> obj, key { obj.dig_fetch(key) }, Hash.new

    it "formats the object with #inspect in the KeyError message" do
      -> { {}.dig_fetch(:foo) }.should raise_error(KeyError, 'key not found: :foo')
      -> { {}.dig_fetch("foo") }.should raise_error(KeyError, 'key not found: "foo"')
      -> { { :foo => { } }.dig_fetch(:foo, :bar) }.should raise_error(KeyError, 'key not found: :bar')
    end
  end

  it "returns the nested value specified by the sequence of keys" do
    h = { foo: { bar: { baz: 1 } } }
    h.dig_fetch(:foo).should == { bar: { baz: 1 } }
    h.dig_fetch(:foo, :bar).should == { baz: 1 }
    h.dig_fetch(:foo, :bar, :baz).should == 1
  end

  it "raises an ArgumentError if no arguments provided" do
    -> { {}.dig_fetch() }.should raise_error(ArgumentError)
  end

  it "raises TypeError if an intermediate element does not respond to #dig_fetch" do
    h = {}
    h[:foo] = [ { bar: [ 1 ] }, [ nil, 'str' ] ]
    -> { h.dig_fetch(:foo, 0, :bar, 0, 0) }.should raise_error(TypeError)
    -> { h.dig_fetch(:foo, 1, 1, 0) }.should raise_error(TypeError)
  end

  it "calls #dig_fetch on the reciever with the remaining arguments" do
    h = { foo: { bar: { baz: 42 } } }
    h[:foo].should_receive(:dig_fetch).with(:bar, :baz).and_return(42)
    h.dig_fetch(:foo, :bar, :baz).should == 42
  end

  it "handles type-mixed deep dig_fetching with array" do
    h = {}
    h[:foo] = [{ bar: [ 1 ] }]

    h.dig_fetch(:foo, 0, :bar).should == [ 1 ]
    h.dig_fetch(:foo, 0, :bar, 0).should == 1
    
    -> { h.dig_fetch(:foo, 0, :bar, 1) }.should raise_error(KeyError)
    -> { h.dig_fetch(:foo, :bar) }.should raise_error(TypeError)
  end

  it "handles type-mixed deep dig_fetching with struct" do
    DummyStruct = Struct.new(:bar)
    
    h = {}
    h[:foo] = DummyStruct.new({ :baz => 1 })

    h.dig_fetch(:foo, :bar, :baz).should == 1
    -> { h.dig_fetch(:foo, :missing) }.should raise_error(KeyError)
  end
end
