require 'test_helper'
require 'zip/ioextras'

class FakeIOTest < MiniTest::Test
  class FakeIOUsingClass
    include ::Zip::IOExtras::FakeIO
  end

  def test_kind_of?
    obj = FakeIOUsingClass.new

    assert(obj.is_a?(Object))
    assert(obj.is_a?(FakeIOUsingClass))
    assert(obj.is_a?(IO))
    assert(!obj.is_a?(Fixnum))
    assert(!obj.is_a?(String))
  end
end
