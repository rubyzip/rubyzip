require 'test_helper'

class DeflaterTest < MiniTest::Unit::TestCase
  include CrcTest

  def test_outputOperator
    txt = load_file("test/data/file2.txt")
    deflate(txt, "deflatertest.bin")
    inflatedTxt = inflate("deflatertest.bin")
    assert_equal(txt, inflatedTxt)
  end

  def test_default_compression
    txt = load_file("test/data/file2.txt")

    Zip.default_compression = ::Zlib::BEST_COMPRESSION
    deflate(txt, "compressiontest_best_compression.bin")
    Zip.default_compression = ::Zlib::DEFAULT_COMPRESSION
    deflate(txt, "compressiontest_default_compression.bin")
    Zip.default_compression = ::Zlib::NO_COMPRESSION
    deflate(txt, "compressiontest_no_compression.bin")

    best    = File.size("compressiontest_best_compression.bin")
    default = File.size("compressiontest_default_compression.bin")
    no      = File.size("compressiontest_no_compression.bin")

    assert(best < default)
    assert(best < no)
    assert(default < no)
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
