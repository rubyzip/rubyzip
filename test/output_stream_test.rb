# frozen_string_literal: true

require_relative 'test_helper'
require_relative 'helpers/assert_entry'

class ZipOutputStreamTest < Minitest::Test
  include AssertEntry

  TEST_ZIP = TestZipFile::TEST_ZIP2.clone
  TEST_ZIP.zip_name = 'test/data/generated/output.zip'

  def test_new
    zos = ::Zip::OutputStream.new(TEST_ZIP.zip_name)
    zos.comment = TEST_ZIP.comment
    write_test_zip(zos)
    zos.close
    assert_test_zip_contents(TEST_ZIP)
  end

  def test_open
    ::Zip::OutputStream.open(TEST_ZIP.zip_name) do |zos|
      zos.comment = TEST_ZIP.comment
      write_test_zip(zos)
    end
    assert_test_zip_contents(TEST_ZIP)
  end

  def test_write_buffer
    buffer = ::Zip::OutputStream.write_buffer(::StringIO.new) do |zos|
      zos.comment = TEST_ZIP.comment
      write_test_zip(zos)
    end
    File.binwrite(TEST_ZIP.zip_name, buffer.string)
    assert_test_zip_contents(TEST_ZIP)
  end

  def test_write_buffer_binmode
    buffer = ::Zip::OutputStream.write_buffer(::StringIO.new) do |zos|
      zos.comment = TEST_ZIP.comment
      write_test_zip(zos)
    end
    assert_equal Encoding::ASCII_8BIT, buffer.external_encoding
  end

  def test_write_buffer_with_temp_file
    tmp_file = Tempfile.new('')

    ::Zip::OutputStream.write_buffer(tmp_file) do |zos|
      zos.comment = TEST_ZIP.comment
      write_test_zip(zos)
    end

    tmp_file.rewind
    File.binwrite(TEST_ZIP.zip_name, tmp_file.read)
    tmp_file.unlink

    assert_test_zip_contents(TEST_ZIP)
  end

  def test_write_buffer_with_temp_file2
    tmp_file = ::File.join(Dir.tmpdir, 'zos.zip')
    ::File.open(tmp_file, 'wb') do |f|
      ::Zip::OutputStream.write_buffer(f) do |zos|
        zos.comment = TEST_ZIP.comment
        write_test_zip(zos)
      end
    end

    ::Zip::File.open(tmp_file) # Should open without error.
  ensure
    ::File.unlink(tmp_file)
  end

  def test_write_buffer_with_default_io
    buffer = ::Zip::OutputStream.write_buffer do |zos|
      zos.comment = TEST_ZIP.comment
      write_test_zip(zos)
    end
    File.binwrite(TEST_ZIP.zip_name, buffer.string)
    assert_test_zip_contents(TEST_ZIP)
  end

  def test_writing_to_closed_stream
    assert_i_o_error_in_closed_stream { |zos| zos << 'hello world' }
    assert_i_o_error_in_closed_stream { |zos| zos.puts 'hello world' }
    assert_i_o_error_in_closed_stream { |zos| zos.write 'hello world' }
  end

  def test_cannot_open_file
    name = TestFiles::EMPTY_TEST_DIR
    begin
      ::Zip::OutputStream.open(name)
    rescue SystemCallError
      assert($ERROR_INFO.kind_of?(Errno::EISDIR) || # Linux
                 $ERROR_INFO.kind_of?(Errno::EEXIST) || # Windows/cygwin
                 $ERROR_INFO.kind_of?(Errno::EACCES), # Windows
             "Expected Errno::EISDIR (or on win/cygwin: Errno::EEXIST), but was: #{$ERROR_INFO.class}")
    end
  end

  def test_put_next_entry
    stored_text = 'hello world in stored text'
    entry_name = 'file1'
    comment = 'my comment'
    ::Zip::OutputStream.open(TEST_ZIP.zip_name) do |zos|
      zos.put_next_entry(entry_name, comment, nil, ::Zip::Entry::STORED)
      zos << stored_text
    end

    assert(File.read(TEST_ZIP.zip_name, mode: 'rb')[stored_text])
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_equal(stored_text, zf.read(entry_name))
    end
  end

  def test_put_next_entry_using_zip_entry_creates_entries_with_correct_timestamps
    file = ::File.open('test/data/file2.txt', 'rb')
    ::Zip::OutputStream.open(TEST_ZIP.zip_name) do |zos|
      zip_entry = ::Zip::Entry.new(
        zos, file.path, time: ::Zip::DOSTime.at(file.mtime)
      )
      zos.put_next_entry(zip_entry)
      zos << file.read
    end

    ::Zip::InputStream.open(TEST_ZIP.zip_name) do |io|
      while (entry = io.get_next_entry)
        # Compare DOS Times, since they are stored with two seconds accuracy
        assert(::Zip::DOSTime.at(file.mtime) == ::Zip::DOSTime.at(entry.mtime))
      end
    end
  end

  def test_chained_put_into_next_entry
    stored_text = 'hello world in stored text'
    stored_text2 = 'with chain'
    entry_name = 'file1'
    comment = 'my comment'
    ::Zip::OutputStream.open(TEST_ZIP.zip_name) do |zos|
      zos.put_next_entry(entry_name, comment, nil, ::Zip::Entry::STORED)
      zos << stored_text << stored_text2
    end

    assert(File.read(TEST_ZIP.zip_name)[stored_text])
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      assert_equal(stored_text + stored_text2, zf.read(entry_name))
    end
  end

  def test_print_deflated
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry('print_test')
      output = zos.print 'hello,', ' world'
      assert_nil(output)
    end

    Zip::InputStream.open(buffer) do |zis|
      entry = zis.get_next_entry
      assert_equal('print_test', entry.name)
      assert_equal('hello, world', zis.read)
    end
  end

  def test_printf_deflated
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry('printf_test')
      output = zos.printf('hello, %s', 'world')
      assert_nil(output)
    end

    Zip::InputStream.open(buffer) do |zis|
      entry = zis.get_next_entry
      assert_equal('printf_test', entry.name)
      assert_equal('hello, world', zis.read)
    end
  end

  def test_write_deflated
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry('write_test')
      output = zos.write 'hello, world'
      assert_equal(12, output)
    end

    Zip::InputStream.open(buffer) do |zis|
      entry = zis.get_next_entry
      assert_equal('write_test', entry.name)
      assert_equal('hello, world', zis.read)
    end
  end

  def test_zip64_default_usage
    buffer = Zip::OutputStream.write_buffer do |zos|
      zos.put_next_entry('write_test')
      zos.write 'hello, world!'
    end

    Zip::InputStream.open(buffer) do |zis|
      entry = zis.get_next_entry
      assert_equal('write_test', entry.name)
      assert(entry.zip64?)
    end
  end

  def test_zip64_default_usage_file
    ::Zip::OutputStream.open(TEST_ZIP.zip_name) do |zos|
      zos.put_next_entry('write_test')
      zos.write 'hello, world!'
    end

    Zip::InputStream.open(TEST_ZIP.zip_name) do |zis|
      entry = zis.get_next_entry
      assert_equal('write_test', entry.name)
      assert(entry.zip64?)
    end
  end

  def assert_i_o_error_in_closed_stream
    assert_raises(IOError) do
      zos = ::Zip::OutputStream.new('test/data/generated/test_putOnClosedStream.zip')
      zos.close
      yield zos
    end
  end

  def write_test_zip(zos)
    TEST_ZIP.entry_names.each do |entry_name|
      zos.put_next_entry(entry_name)
      File.open(entry_name, 'rb') { |f| zos.write(f.read) }
    end
  end
end
