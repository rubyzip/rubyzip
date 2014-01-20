require 'test_helper'

class DeflaterTest < MiniTest::Unit::TestCase
  include CrcTest

  def test_outputOperator
    txt = load_file("test/data/file2.txt")
    deflate(txt, "deflatertest.bin")
    inflatedTxt = inflate("deflatertest.bin")
    assert_equal(txt, inflatedTxt)
  end

  private
  def load_file(fileName)
    txt = nil
    File.open(fileName, "rb") { |f| txt = f.read }
  end

  def deflate(data, fileName)
    File.open(fileName, "wb") {
        |file|
      deflater = ::Zip::Deflater.new(file)
      deflater << data
      deflater.finish
      assert_equal(deflater.size, data.size)
      file << "trailing data for zlib with -MAX_WBITS"
    }
  end

  def inflate(fileName)
    txt = nil
    File.open(fileName, "rb") {
        |file|
      inflater = ::Zip::Inflater.new(file)
      txt = inflater.sysread
    }
  end

  def test_crc
    run_crc_test(::Zip::Deflater)
  end
end
