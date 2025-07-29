# frozen_string_literal: true

module CrcTests
  class TestOutputStream
    include ::Zip::IOExtras::AbstractOutputStream

    attr_accessor :buffer

    def initialize
      @buffer = +''
    end

    def <<(data)
      @buffer << data
      self
    end
  end

  def run_crc_test(compressor_class)
    str = "Here's a nice little text to compute the crc for! Ho hum, it is nice nice nice nice indeed."
    fake_out = TestOutputStream.new

    deflater = compressor_class.new(fake_out)
    deflater << str
    assert_equal(0x919920fc, deflater.crc)
  end
end
