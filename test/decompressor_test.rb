require 'test_helper'
class DecompressorTest < MiniTest::Test
  TEST_COMPRESSION_METHOD = 255

  class TestCompressionClass
  end

  def test_decompressor_registration
    assert_nil(::Zip::Decompressor.find_by_compression_method(TEST_COMPRESSION_METHOD))

    ::Zip::Decompressor.register(TEST_COMPRESSION_METHOD, TestCompressionClass)

    assert_equal(TestCompressionClass, ::Zip::Decompressor.find_by_compression_method(TEST_COMPRESSION_METHOD))
  end
end
