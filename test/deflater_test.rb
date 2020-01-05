require 'test_helper'

class DeflaterTest < MiniTest::Test
  include CrcTest

  DEFLATER_TEST_FILE = 'test/data/generated/deflatertest.bin'
  BEST_COMP_FILE = 'test/data/generated/compressiontest_best_compression.bin'
  DEFAULT_COMP_FILE = 'test/data/generated/compressiontest_default_compression.bin'
  NO_COMP_FILE = 'test/data/generated/compressiontest_no_compression.bin'

  def test_output_operator
    txt = load_file('test/data/file2.txt')
    deflate(txt, DEFLATER_TEST_FILE)
    inflatedTxt = inflate(DEFLATER_TEST_FILE)
    assert_equal(txt, inflatedTxt)
  end

  def test_default_compression
    txt = load_file('test/data/file2.txt')

    Zip.default_compression = ::Zlib::BEST_COMPRESSION
    deflate(txt, BEST_COMP_FILE)
    Zip.default_compression = ::Zlib::DEFAULT_COMPRESSION
    deflate(txt, DEFAULT_COMP_FILE)
    Zip.default_compression = ::Zlib::NO_COMPRESSION
    deflate(txt, NO_COMP_FILE)

    best    = File.size(BEST_COMP_FILE)
    default = File.size(DEFAULT_COMP_FILE)
    no      = File.size(NO_COMP_FILE)

    assert(best < default)
    assert(best < no)
    assert(default < no)
  end

  def test_data_error
    assert_raises(::Zip::DecompressionError) do
      inflate('test/data/file1.txt.corrupt.deflatedData')
    end
  end

  private

  def load_file(fileName)
    File.open(fileName, 'rb') { |f| f.read }
  end

  def deflate(data, fileName)
    File.open(fileName, 'wb') do |file|
      deflater = ::Zip::Deflater.new(file)
      deflater << data
      deflater.finish
      assert_equal(deflater.size, data.size)
      file << 'trailing data for zlib with -MAX_WBITS'
    end
  end

  def inflate(fileName)
    File.open(fileName, 'rb') do |file|
      inflater = ::Zip::Inflater.new(file)
      inflater.read
    end
  end

  def test_crc
    run_crc_test(::Zip::Deflater)
  end
end
