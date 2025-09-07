# frozen_string_literal: true

require 'simplecov'
require 'minitest/autorun'
require 'minitest/unit'
require 'fileutils'
require 'tmpdir'
require 'digest/sha1'
require 'zip'
require 'gentestfiles'

TestFiles.create_test_files
TestZipFile.create_test_zips

MiniTest.after_run do
  FileUtils.rm_rf('test/data/generated')
end

module DecompressorTests
  # expects @ref_text, @ref_lines and @decompressor

  TEST_FILE = 'test/data/file1.txt'

  def setup
    @ref_text = ''
    File.open(TEST_FILE, 'rb') { |f| @ref_text = f.read }
    @ref_lines = @ref_text.split($INPUT_RECORD_SEPARATOR)
  end

  def test_read_everything
    assert_equal(@ref_text, @decompressor.read)
  end

  def test_read_in_chunks
    size = 5
    while (chunk = @decompressor.read(size))
      assert_equal(@ref_text.slice!(0, size), chunk)
    end
    assert_equal(0, @ref_text.size)
  end
end

module AssertEntry
  def assert_next_entry(filename, zis)
    assert_entry(filename, zis, zis.get_next_entry.name)
  end

  def assert_entry(filename, zis, entry_name)
    assert_equal(filename, entry_name)
    assert_entry_contents_for_stream(filename, zis, entry_name)
  end

  def assert_entry_contents_for_stream(filename, zis, entry_name)
    File.open(filename, 'rb') do |file|
      expected = file.read
      actual = zis.read
      if expected != actual
        if expected && actual && (expected.length > 400 || actual.length > 400)
          entry_filename = "#{entry_name}.zipEntry"
          File.open(entry_filename, 'wb') { |entryfile| entryfile << actual }
          raise("File '#{filename}' is different from '#{entry_filename}'")
        else
          assert_equal(expected, actual)
        end
      end
    end
  end

  def self.assert_contents(filename, string)
    contents = ''
    File.open(filename, 'rb') { |f| contents = f.read }
    return unless contents != string

    if contents.length > 400 || string.length > 400
      string_file = "#{filename}.other"
      File.open(string_file, 'wb') { |f| f << string }
      raise("File '#{filename}' is different from contents of string stored in '#{string_file}'")
    else
      assert_equal(contents, string)
    end
  end

  def assert_stream_contents(zis, zip_file)
    assert(!zis.nil?)
    zip_file.entry_names.each do |entry_name|
      assert_next_entry(entry_name, zis)
    end
    assert_nil(zis.get_next_entry)
  end

  def assert_test_zip_contents(zip_file)
    ::Zip::InputStream.open(zip_file.zip_name) do |zis|
      assert_stream_contents(zis, zip_file)
    end
  end

  def assert_entry_contents(zip_file, entry_name, filename = entry_name.to_s)
    zis = zip_file.get_input_stream(entry_name)
    assert_entry_contents_for_stream(filename, zis, entry_name)
  ensure
    zis.close if zis
  end
end

module CrcTest
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

module CommonZipFileFixture
  include AssertEntry

  EMPTY_FILENAME = 'emptyZipFile.zip'

  TEST_ZIP = TestZipFile::TEST_ZIP2.clone
  TEST_ZIP.zip_name = 'test/data/generated/5entry_copy.zip'

  def setup
    FileUtils.rm_f(EMPTY_FILENAME)
    FileUtils.cp(TestZipFile::TEST_ZIP2.zip_name, TEST_ZIP.zip_name)
  end
end

module ExtraAssertions
  def assert_forwarded(object, method, ret_val, *expected_args)
    call_args = nil
    object.singleton_class.class_exec do
      alias_method :"#{method}_org", method
      define_method(method) do |*args|
        call_args = args
        ret_val
      end
    end

    assert_equal(ret_val, yield) # Invoke test
    assert_equal(expected_args, call_args)
  ensure
    object.singleton_class.class_exec do
      remove_method method
      alias_method method, :"#{method}_org"
    end
  end
end

module ZipEntryData
  TEST_ZIPFILE = 'someZipFile.zip'
  TEST_COMMENT = 'a comment'
  TEST_COMPRESSED_SIZE = 1234
  TEST_CRC = 325_324
  TEST_EXTRA = 'Some data here'
  TEST_COMPRESSIONMETHOD = ::Zip::Entry::DEFLATED
  TEST_COMPRESSIONLEVEL = ::Zip.default_compression
  TEST_NAME = 'entry name'
  TEST_SIZE = 8432
  TEST_ISDIRECTORY = false
  TEST_TIME = Time.now
end
