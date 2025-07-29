# frozen_string_literal: true

require 'test_helper'

class DeflaterTest < Minitest::Test
  include CrcTest

  DEFLATER_TEST_FILE = 'test/data/generated/deflatertest.bin'
  BEST_COMP_FILE = 'test/data/generated/compressiontest_best_compression.bin'
  DEFAULT_COMP_FILE = 'test/data/generated/compressiontest_default_compression.bin'
  NO_COMP_FILE = 'test/data/generated/compressiontest_no_compression.bin'

  def teardown
    Zip.reset!
  end

  # Remove this test when JRuby#3962 is fixed.
  def test_deflate_strategy
    if defined?(JRUBY_VERSION)
      assert_equal(Zlib::SYNC_FLUSH, Zip::ZLIB_FLUSHING_STRATEGY)
    else
      assert_equal(Zlib::NO_FLUSH, Zip::ZLIB_FLUSHING_STRATEGY)
    end
  end

  def test_output_operator
    txt = load_file('test/data/file2.txt')
    deflate(txt, DEFLATER_TEST_FILE)
    inflated_txt = inflate(DEFLATER_TEST_FILE)
    assert_equal(txt, inflated_txt)
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

  def load_file(filename)
    File.binread(filename)
  end

  def deflate(data, filename)
    File.open(filename, 'wb') do |file|
      deflater = ::Zip::Deflater.new(file)
      deflater << data
      deflater.finish
      assert_equal(deflater.size, data.size)
      file << 'trailing data for zlib with -MAX_WBITS'
    end
  end

  def inflate(filename)
    File.open(filename, 'rb') do |file|
      inflater = ::Zip::Inflater.new(file)
      inflater.read
    end
  end

  def test_crc
    run_crc_test(::Zip::Deflater)
  end
end
