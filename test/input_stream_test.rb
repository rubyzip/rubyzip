# frozen_string_literal: true

require 'test_helper'

class ZipInputStreamTest < MiniTest::Test
  include AssertEntry

  class IOLike
    extend Forwardable

    def initialize(path, mode)
      @file = File.new(path, mode)
    end

    delegate ::Zip::File::IO_METHODS => :@file
  end

  def test_new
    zis = ::Zip::InputStream.new(TestZipFile::TEST_ZIP2.zip_name)
    assert_stream_contents(zis, TestZipFile::TEST_ZIP2)
    assert_equal(true, zis.eof?)
    zis.close
  end

  def test_open_with_block
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      assert_stream_contents(zis, TestZipFile::TEST_ZIP2)
      assert_equal(true, zis.eof?)
    end
  end

  def test_open_without_block
    zis = ::Zip::InputStream.open(File.new(TestZipFile::TEST_ZIP2.zip_name, 'rb'))
    assert_stream_contents(zis, TestZipFile::TEST_ZIP2)
  end

  def test_open_buffer_with_block
    ::Zip::InputStream.open(File.new(TestZipFile::TEST_ZIP2.zip_name, 'rb')) do |zis|
      assert_stream_contents(zis, TestZipFile::TEST_ZIP2)
      assert_equal(true, zis.eof?)
    end
  end

  def test_open_string_io_without_block
    string_io = ::StringIO.new(::File.read(TestZipFile::TEST_ZIP2.zip_name, mode: 'rb'))
    zis = ::Zip::InputStream.open(string_io)
    assert_stream_contents(zis, TestZipFile::TEST_ZIP2)
  end

  def test_open_string_io_with_block
    string_io = ::StringIO.new(::File.read(TestZipFile::TEST_ZIP2.zip_name, mode: 'rb'))
    ::Zip::InputStream.open(string_io) do |zis|
      assert_stream_contents(zis, TestZipFile::TEST_ZIP2)
      assert_equal(true, zis.eof?)
    end
  end

  def test_open_buffer_without_block
    zis = ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name)
    assert_stream_contents(zis, TestZipFile::TEST_ZIP2)
  end

  def test_open_io_like_with_block
    ::Zip::InputStream.open(IOLike.new(TestZipFile::TEST_ZIP2.zip_name, 'rb')) do |zis|
      assert_stream_contents(zis, TestZipFile::TEST_ZIP2)
      assert_equal(true, zis.eof?)
    end
  end

  def test_open_file_with_gp3bit_set
    ::Zip::InputStream.open('test/data/gpbit3stored.zip') do |zis|
      error = assert_raises(::Zip::StreamingError) do
        zis.get_next_entry
      end
      assert_match(/file1\.txt/, error.message)
      assert_equal('file1.txt', error.entry.name)
    end
  end

  def test_open_file_with_gp3bit_set_created_by_osx_archive
    ::Zip::InputStream.open('test/data/osx-archive.zip') do |zis|
      error = assert_raises(::Zip::StreamingError) do
        zis.get_next_entry
      end
      assert_match(/1\.txt/, error.message)
      assert_equal('1.txt', error.entry.name)
    end
  end

  def test_open_split_archive_raises_error
    ::Zip::InputStream.open('test/data/invalid-split.zip') do |zis|
      error = assert_raises(::Zip::SplitArchiveError) do
        zis.get_next_entry
      end
      refute(error.message.empty?)
    end
  end

  def test_open_encrypted_archive_raises_error
    ::Zip::InputStream.open('test/data/zipWithEncryption.zip') do |zis|
      assert_raises(::Zip::Error) do
        zis.get_next_entry
      end
    end
  end

  def test_size_no_entry
    zis = ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name)
    assert_nil(zis.size)
  end

  def test_size_with_entry
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      zis.get_next_entry
      assert_equal(123_702, zis.size)
    end
  end

  def test_get_entry_ftypes
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP4.zip_name) do |zis|
      entry = zis.get_next_entry
      assert_equal(:file, entry.ftype)

      entry = zis.get_next_entry
      assert_equal(:directory, entry.ftype)
    end
  end

  def test_incomplete_reads
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      entry = zis.get_next_entry # longAscii.txt
      assert_equal(false, zis.eof?)
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[0], entry.name)
      assert !zis.gets.empty?
      assert_equal(false, zis.eof?)
      entry = zis.get_next_entry # empty.txt
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[1], entry.name)
      assert_equal(0, entry.size)
      assert_nil(zis.gets)
      assert_equal(true, zis.eof?)
      entry = zis.get_next_entry # empty_chmod640.txt
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[2], entry.name)
      assert_equal(0, entry.size)
      assert_nil(zis.gets)
      assert_equal(true, zis.eof?)
      entry = zis.get_next_entry # short.txt
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[3], entry.name)
      assert !zis.gets.empty?
      entry = zis.get_next_entry # longBinary.bin
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[4], entry.name)
      assert !zis.gets.empty?
    end
  end

  def test_incomplete_reads_from_string_io
    string_io = ::StringIO.new(::File.read(TestZipFile::TEST_ZIP2.zip_name, mode: 'rb'))
    ::Zip::InputStream.open(string_io) do |zis|
      entry = zis.get_next_entry # longAscii.txt
      assert_equal(false, zis.eof?)
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[0], entry.name)
      assert !zis.gets.empty?
      assert_equal(false, zis.eof?)
      entry = zis.get_next_entry # empty.txt
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[1], entry.name)
      assert_equal(0, entry.size)
      assert_nil(zis.gets)
      assert_equal(true, zis.eof?)
      entry = zis.get_next_entry # empty_chmod640.txt
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[2], entry.name)
      assert_equal(0, entry.size)
      assert_nil(zis.gets)
      assert_equal(true, zis.eof?)
      entry = zis.get_next_entry # short.txt
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[3], entry.name)
      assert !zis.gets.empty?
      entry = zis.get_next_entry # longBinary.bin
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[4], entry.name)
      assert !zis.gets.empty?
    end
  end

  def test_read_with_number_of_bytes_returns_nil_at_eof
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      entry = zis.get_next_entry # longAscii.txt
      zis.read(entry.size)
      assert_equal(true, zis.eof?)
      assert_nil(zis.read(1))
      assert_nil(zis.read(1))
    end
  end

  def test_read_with_zero_returns_empty_string
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      assert_equal('', zis.read(0))
    end
  end

  def test_rewind
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      e = zis.get_next_entry
      assert_equal(TestZipFile::TEST_ZIP2.entry_names[0], e.name)

      # Do a little reading
      buf = +''
      buf << zis.read(100)
      assert_equal(100, zis.pos)
      buf << (zis.gets || '')
      buf << (zis.gets || '')
      assert_equal(false, zis.eof?)

      zis.rewind

      buf2 = +''
      buf2 << zis.read(100)
      buf2 << (zis.gets || '')
      buf2 << (zis.gets || '')

      assert_equal(buf, buf2)

      zis.rewind
      assert_equal(false, zis.eof?)
      assert_equal(0, zis.pos)

      assert_entry(e.name, zis, e.name)
    end
  end

  def test_mix_read_and_gets
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      zis.get_next_entry
      assert_equal('#!/usr/bin/env ruby', zis.gets.chomp)
      assert_equal(false, zis.eof?)
      assert_equal('', zis.gets.chomp)
      assert_equal(false, zis.eof?)
      assert_equal('$VERBOSE =', zis.read(10))
      assert_equal(false, zis.eof?)
    end
  end

  def test_ungetc
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      zis.get_next_entry
      first_line = zis.gets.chomp
      first_line.reverse.bytes.each { |b| zis.ungetc(b) }
      assert_equal('#!/usr/bin/env ruby', zis.gets.chomp)
      assert_equal('$VERBOSE =', zis.read(10))
    end
  end

  def test_readline_then_read
    ::Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      zis.get_next_entry
      assert_equal("#!/usr/bin/env ruby\n", zis.readline)
      refute(zis.eof?)
      refute_empty(zis.read) # Also should not raise an error.
      assert(zis.eof?)
    end
  end

  def test_sysread
    Zip::InputStream.open(TestZipFile::TEST_ZIP2.zip_name) do |zis|
      zis.get_next_entry

      # Read with no buffer specified.
      buffer = zis.sysread(20)
      assert_equal("#!/usr/bin/env ruby\n", buffer)

      # Read with a buffer specified.
      buffer = +''
      zis.sysread(17, buffer)
      assert_equal("\n$VERBOSE = true\n", buffer)

      # Read with no length specified. This should read the rest of the entry.
      buffer = zis.sysread
      assert_equal(123_665, buffer.bytesize)
    end
  end
end
