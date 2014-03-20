require 'test_helper'
require 'rubyzip/ioextras'

class FakeIOTest < MiniTest::Unit::TestCase
  class FakeIOUsingClass
    include ::RubyZip::IOExtras::FakeIO
  end

  def test_kind_of?
    obj = FakeIOUsingClass.new

    assert(obj.kind_of?(Object))
    assert(obj.kind_of?(FakeIOUsingClass))
    assert(obj.kind_of?(IO))
    assert(!obj.kind_of?(Fixnum))
    assert(!obj.kind_of?(String))
  end
end
