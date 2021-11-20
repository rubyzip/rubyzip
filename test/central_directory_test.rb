# frozen_string_literal: true

require 'test_helper'

class ZipCentralDirectoryTest < MiniTest::Test
  def teardown
    ::Zip.reset!
  end

  def test_read_from_stream
    ::File.open(TestZipFile::TEST_ZIP2.zip_name, 'rb') do |zip_file|
      cdir = ::Zip::CentralDirectory.read_from_stream(zip_file)

      assert_equal(TestZipFile::TEST_ZIP2.entry_names.size, cdir.size)
      assert_equal(cdir.entries.map(&:name).sort, TestZipFile::TEST_ZIP2.entry_names.sort)
      assert_equal(TestZipFile::TEST_ZIP2.comment, cdir.comment)
    end
  end

  def test_read_from_invalid_stream
    File.open('test/data/file2.txt', 'rb') do |zip_file|
      cdir = ::Zip::CentralDirectory.new
      cdir.read_from_stream(zip_file)
    end
    raise 'ZipError expected!'
  rescue ::Zip::Error
  end

  def test_read_eocd_with_wrong_cdir_offset_from_file
    ::File.open('test/data/testDirectory.bin', 'rb') do |f|
      assert_raises(::Zip::Error) do
        cdir = ::Zip::CentralDirectory.new
        cdir.read_from_stream(f)
      end
    end
  end

  def test_read_eocd_with_wrong_cdir_offset_from_buffer
    ::File.open('test/data/testDirectory.bin', 'rb') do |f|
      assert_raises(::Zip::Error) do
        cdir = ::Zip::CentralDirectory.new
        cdir.read_from_stream(StringIO.new(f.read))
      end
    end
  end

  def test_count_entries
    [
      ['test/data/osx-archive.zip', 4],
      ['test/data/zip64-sample.zip', 2],
      ['test/data/max_length_file_comment.zip', 1],
      ['test/data/100000-files.zip', 100_000]
    ].each do |filename, num_entries|
      cdir = ::Zip::CentralDirectory.new

      ::File.open(filename, 'rb') do |f|
        assert_equal(num_entries, cdir.count_entries(f))

        f.seek(0)
        s = StringIO.new(f.read)
        assert_equal(num_entries, cdir.count_entries(s))
      end
    end
  end

  def test_write_to_stream
    entries = [
      ::Zip::Entry.new(
        'file.zip', 'flimse',
        comment: 'myComment', extra: 'somethingExtra'
      ),
      ::Zip::Entry.new('file.zip', 'secondEntryName'),
      ::Zip::Entry.new('file.zip', 'lastEntry.txt', comment: 'Has a comment')
    ]

    cdir = ::Zip::CentralDirectory.new(entries, 'my zip comment')
    File.open('test/data/generated/cdirtest.bin', 'wb') do |f|
      cdir.write_to_stream(f)
    end

    cdir_readback = ::Zip::CentralDirectory.new
    File.open('test/data/generated/cdirtest.bin', 'rb') do |f|
      cdir_readback.read_from_stream(f)
    end

    assert_equal(cdir.entries.sort, cdir_readback.entries.sort)
  end

  def test_write64_to_stream
    ::Zip.write_zip64_support = true
    entries = [
      ::Zip::Entry.new(
        'file.zip', 'file1-little', comment: 'comment1', size: 200,
        compressed_size: 200, crc: 101,
        compression_method: ::Zip::Entry::STORED
      ),
      ::Zip::Entry.new(
        'file.zip', 'file2-big', comment: 'comment2',
        size: 20_000_000_000, compressed_size: 18_000_000_000, crc: 102
      ),
      ::Zip::Entry.new(
        'file.zip', 'file3-alsobig', comment: 'comment3',
        size: 21_000_000_000, compressed_size: 15_000_000_000, crc: 103
      ),
      ::Zip::Entry.new(
        'file.zip', 'file4-little', comment: 'comment4',
        size: 121, compressed_size: 100, crc: 104
      )
    ]

    [0, 250, 18_000_000_300, 33_000_000_350].each_with_index do |offset, index|
      entries[index].local_header_offset = offset
    end

    cdir = ::Zip::CentralDirectory.new(entries, 'zip comment')
    File.open('test/data/generated/cdir64test.bin', 'wb') do |f|
      cdir.write_to_stream(f)
    end

    cdir_readback = ::Zip::CentralDirectory.new
    File.open('test/data/generated/cdir64test.bin', 'rb') do |f|
      cdir_readback.read_from_stream(f)
    end

    assert_equal(cdir.entries.sort, cdir_readback.entries.sort)
    assert_equal(::Zip::VERSION_NEEDED_TO_EXTRACT_ZIP64, cdir_readback.instance_variable_get(:@version_needed_for_extract))
  end

  def test_equality
    cdir1 = ::Zip::CentralDirectory.new(
      [
        ::Zip::Entry.new('file.zip', 'flimse', extra: 'somethingExtra'),
        ::Zip::Entry.new('file.zip', 'secondEntryName'),
        ::Zip::Entry.new('file.zip', 'lastEntry.txt')
      ],
      'my zip comment'
    )
    cdir2 = ::Zip::CentralDirectory.new(
      [
        ::Zip::Entry.new('file.zip', 'flimse', extra: 'somethingExtra'),
        ::Zip::Entry.new('file.zip', 'secondEntryName'),
        ::Zip::Entry.new('file.zip', 'lastEntry.txt')
      ],
      'my zip comment'
    )
    cdir3 = ::Zip::CentralDirectory.new(
      [
        ::Zip::Entry.new('file.zip', 'flimse', extra: 'somethingExtra'),
        ::Zip::Entry.new('file.zip', 'secondEntryName'),
        ::Zip::Entry.new('file.zip', 'lastEntry.txt')
      ],
      'comment?'
    )
    cdir4 = ::Zip::CentralDirectory.new(
      [
        ::Zip::Entry.new('file.zip', 'flimse', extra: 'somethingExtra'),
        ::Zip::Entry.new('file.zip', 'lastEntry.txt')
      ],
      'comment?'
    )
    assert_equal(cdir1, cdir1)
    assert_equal(cdir1, cdir2)

    assert(cdir1 != cdir3)
    assert(cdir2 != cdir3)
    assert(cdir2 != cdir3)
    assert(cdir3 != cdir4)

    assert(cdir3 != 'hello')
  end
end
