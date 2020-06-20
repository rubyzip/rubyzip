require 'test_helper'

class ZipLocalEntryTest < MiniTest::Test
  CEH_FILE = 'test/data/generated/centralEntryHeader.bin'
  LEH_FILE = 'test/data/generated/localEntryHeader.bin'

  def teardown
    ::Zip.reset!
  end

  def test_read_local_entry_header_of_first_test_zip_entry
    ::File.open(TestZipFile::TEST_ZIP3.zip_name, 'rb') do |file|
      entry = ::Zip::Entry.read_local_entry(file)

      assert_equal('', entry.comment)
      # Differs from windows and unix because of CR LF
      # assert_equal(480, entry.compressed_size)
      # assert_equal(0x2a27930f, entry.crc)
      # extra field is 21 bytes long
      # probably contains some unix attrutes or something
      # disabled: assert_equal(nil, entry.extra)
      assert_equal(::Zip::Entry::DEFLATED, entry.compression_method)
      assert_equal(TestZipFile::TEST_ZIP3.entry_names[0], entry.name)
      assert_equal(::File.size(TestZipFile::TEST_ZIP3.entry_names[0]), entry.size)
      assert(!entry.directory?)
    end
  end

  def test_read_date_time
    ::File.open('test/data/rubycode.zip', 'rb') do |file|
      entry = ::Zip::Entry.read_local_entry(file)
      assert_equal('zippedruby1.rb', entry.name)
      assert_equal(::Zip::DOSTime.at(1_019_261_638), entry.time)
    end
  end

  def test_read_local_entry_from_non_zip_file
    ::File.open('test/data/file2.txt') do |file|
      assert_nil(::Zip::Entry.read_local_entry(file))
    end
  end

  def test_read_local_entry_from_truncated_zip_file
    fragment = ''
    # local header is at least 30 bytes
    ::File.open(TestZipFile::TEST_ZIP2.zip_name) { |f| fragment = f.read(12) }

    fragment.extend(IOizeString).reset
    entry = ::Zip::Entry.new
    entry.read_local_entry(fragment)
    raise 'ZipError expected'
  rescue ::Zip::Error
  end

  def test_write_entry
    entry = ::Zip::Entry.new(
      'file.zip', 'entry_name', comment: 'my little comment', size: 400,
      extra: 'thisIsSomeExtraInformation', compressed_size: 100, crc: 987_654
    )

    write_to_file(LEH_FILE, CEH_FILE, entry)
    local_entry, central_entry = read_from_file(LEH_FILE, CEH_FILE)
    assert(
      central_entry.extra['Zip64Placeholder'].nil?,
      'zip64 placeholder should not be used in central directory'
    )
    compare_local_entry_headers(entry, local_entry)
    compare_c_dir_entry_headers(entry, central_entry)
  end

  def test_write_entry_with_zip64
    ::Zip.write_zip64_support = true
    entry = ::Zip::Entry.new(
      'file.zip', 'entry_name', comment: 'my little comment', size: 400,
      extra: 'thisIsSomeExtraInformation', compressed_size: 100, crc: 987_654
    )

    write_to_file(LEH_FILE, CEH_FILE, entry)
    local_entry, central_entry = read_from_file(LEH_FILE, CEH_FILE)
    assert(
      local_entry.extra['Zip64Placeholder'],
      'zip64 placeholder should be used in local file header'
    )

    # This was removed when writing the c_dir_entry, so remove from compare.
    local_entry.extra.delete('Zip64Placeholder')
    assert(
      central_entry.extra['Zip64Placeholder'].nil?,
      'zip64 placeholder should not be used in central directory'
    )

    compare_local_entry_headers(entry, local_entry)
    compare_c_dir_entry_headers(entry, central_entry)
  end

  def test_write_64entry
    ::Zip.write_zip64_support = true
    entry = ::Zip::Entry.new(
      'bigfile.zip', 'entry_name', comment: 'my little equine',
      extra: 'malformed extra field because why not', size: 0x9988776655443322,
      compressed_size: 0x7766554433221100, crc: 0xDEADBEEF
    )

    write_to_file(LEH_FILE, CEH_FILE, entry)
    local_entry, central_entry = read_from_file(LEH_FILE, CEH_FILE)
    compare_local_entry_headers(entry, local_entry)
    compare_c_dir_entry_headers(entry, central_entry)
  end

  def test_rewrite_local_header64
    ::Zip.write_zip64_support = true
    buf1 = StringIO.new
    entry = ::Zip::Entry.new('file.zip', 'entry_name')
    entry.write_local_entry(buf1)
    assert(entry.extra['Zip64'].nil?, 'zip64 extra is unnecessarily present')

    buf2 = StringIO.new
    entry.size = 0x123456789ABCDEF0
    entry.compressed_size = 0x0123456789ABCDEF
    entry.write_local_entry(buf2, true)
    refute_nil(entry.extra['Zip64'])
    refute_equal(buf1.size, 0)
    assert_equal(buf1.size, buf2.size) # it can't grow, or we'd clobber file data
  end

  def test_read_local_offset
    entry = ::Zip::Entry.new('file.zip', 'entry_name')
    entry.local_header_offset = 12_345
    ::File.open(CEH_FILE, 'wb') { |f| entry.write_c_dir_entry(f) }
    read_entry = nil
    ::File.open(CEH_FILE, 'rb') { |f| read_entry = ::Zip::Entry.read_c_dir_entry(f) }
    compare_c_dir_entry_headers(entry, read_entry)
  end

  def test_read64_local_offset
    ::Zip.write_zip64_support = true
    entry = ::Zip::Entry.new('file.zip', 'entry_name')
    entry.local_header_offset = 0x0123456789ABCDEF
    ::File.open(CEH_FILE, 'wb') { |f| entry.write_c_dir_entry(f) }
    read_entry = nil
    ::File.open(CEH_FILE, 'rb') { |f| read_entry = ::Zip::Entry.read_c_dir_entry(f) }
    compare_c_dir_entry_headers(entry, read_entry)
  end

  private

  def compare_local_entry_headers(entry1, entry2)
    assert_equal(entry1.compressed_size, entry2.compressed_size)
    assert_equal(entry1.crc, entry2.crc)
    assert_equal(entry1.extra, entry2.extra)
    assert_equal(entry1.compression_method, entry2.compression_method)
    assert_equal(entry1.name, entry2.name)
    assert_equal(entry1.size, entry2.size)
    assert_equal(entry1.local_header_offset, entry2.local_header_offset)
  end

  def compare_c_dir_entry_headers(entry1, entry2)
    compare_local_entry_headers(entry1, entry2)
    assert_equal(entry1.comment, entry2.comment)
  end

  def write_to_file(local_filename, central_filename, entry)
    ::File.open(local_filename, 'wb') { |f| entry.write_local_entry(f) }
    ::File.open(central_filename, 'wb') { |f| entry.write_c_dir_entry(f) }
  end

  def read_from_file(local_filename, central_filename)
    local_entry = nil
    cdir_entry = nil

    ::File.open(local_filename, 'rb') do |f|
      local_entry = ::Zip::Entry.read_local_entry(f)
    end

    ::File.open(central_filename, 'rb') do |f|
      cdir_entry = ::Zip::Entry.read_c_dir_entry(f)
    end

    [local_entry, cdir_entry]
  end
end
