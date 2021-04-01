require_relative '../../spec_helper'

describe "Array#dig_fetch" do

  it "returns #at with one arg" do
    ['a'].dig_fetch(0).should == 'a'
    -> { ['a'].dig_fetch(1) }.should raise_error(KeyError)
  end

  it "recurses array elements" do
    a = [ [ 1, [2, '3'] ] ]
    a.dig_fetch(0, 0).should == 1
    a.dig_fetch(0, 1, 1).should == '3'
    a.dig_fetch(0, -1, 0).should == 2
  end

  it "returns the nested value specified if the sequence includes a key" do
    a = [42, { foo: :bar }]
    a.dig_fetch(1, :foo).should == :bar
  end

  it "raises a TypeError for a non-numeric index" do
    -> {
      ['a'].dig_fetch(:first)
    }.should raise_error(TypeError)
  end

  it "raises a TypeError if any intermediate step does not respond to #dig_fetch" do
    a = [1, 2]
    -> {
      a.dig_fetch(0, 1)
    }.should raise_error(TypeError)
  end

  it "raises an ArgumentError if no arguments provided" do
    -> {
      [10].dig_fetch()
    }.should raise_error(ArgumentError)
  end

  it "raises KeyError if any intermediate step is nil" do
    a = [[1, [2, 3]]]
    -> { a.dig_fetch(1, 2, 3) }.should raise_error(KeyError)
  end

  it "calls #dig_fetch on the result of #at with the remaining arguments" do
    h = [[nil, [nil, nil, 42]]]
    h[0].should_receive(:dig_fetch).with(1, 2).and_return(42)
    h.dig_fetch(0, 1, 2).should == 42
  end

end
