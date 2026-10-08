# frozen_string_literal: true

require_relative 'test_helper'

require 'fileutils'
require 'tmpdir'
require 'zip/filesystem'

class ExtraFieldsTest < Minitest::Test
  TEST_ZIP = 'test/data/zipWithDirs.zip'
  TEST_ATIME = ::Zip::DOSTime.at(1_027_694_306)

  ODD_EXTRA_ZIP = 'test/data/oddExtraField.zip'

  FIXTURES = %w[
    test/data/zipWithDirs.zip
    test/data/oddExtraField.zip
    test/data/ntfs.zip
    test/data/osx-archive.zip
    test/data/zip64-sample.zip
    test/data/local_extra_field.zip
  ].freeze

  PRELOAD_SETTINGS = [true, false].freeze

  METADATA = [
    :name, :size, :compressed_size, :crc,
    :compression_method, :local_header_offset, :mtime
  ].freeze

  class SeekRecordingIO < ::StringIO
    attr_reader :seeks

    def initialize(*args)
      super
      @seeks = []
    end

    def seek(amount, whence = IO::SEEK_SET)
      @seeks << [amount, whence]
      super
    end
  end

  def teardown
    ::Zip.reset!
  end

  def recording_io(path = TEST_ZIP)
    SeekRecordingIO.new(::File.binread(path))
  end

  # Excludes the first entry, at offset 0, which is also where the search for
  # the end of central directory record starts in an archive this small.
  def local_header_offsets
    ::Zip::File.new(TEST_ZIP).entries.map(&:local_header_offset) - [0]
  end

  def copy_first_entry_of(path)
    entry = ::Zip::File.open(path).entries.find(&:file?)
    ::Zip::OutputStream.write_buffer(::StringIO.new(+'')) do |zos|
      zos.copy_raw_entry(entry)
    end.string
  end

  def local_headers_visited_by(io)
    offsets = local_header_offsets
    io.seeks.filter_map do |amount, whence|
      amount if whence == IO::SEEK_SET && offsets.include?(amount)
    end
  end

  def test_preloading_is_on_by_default
    assert(::Zip.preload_extra_fields)
  end

  def test_local_headers_are_read_by_default
    entry = ::Zip::File.new(TEST_ZIP).find_entry('file1')

    assert_equal(500, entry.extra[:iunix].uid)
    assert_equal(TEST_ATIME, entry.atime)
  end

  def test_local_headers_are_not_visited_when_preloading_is_off
    ::Zip.preload_extra_fields = false
    io = recording_io
    ::Zip::File.open_buffer(io)

    assert_empty(local_headers_visited_by(io))
  end

  def test_local_headers_are_visited_when_preloading_is_on
    io = recording_io
    ::Zip::File.open_buffer(io)

    assert_equal(local_header_offsets.sort, local_headers_visited_by(io).sort)
  end

  def test_only_central_directory_fields_are_present_before_reading_an_entry
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.new(TEST_ZIP).find_entry('file1')

    assert_nil(entry.extra[:iunix].uid)
    assert_nil(entry.atime)
  end

  def test_local_fields_are_picked_up_when_an_entry_is_read
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.new(TEST_ZIP).find_entry('file1')
    entry.get_input_stream(&:read)

    assert_equal(500, entry.extra[:iunix].uid)
    assert_equal(500, entry.extra[:iunix].gid)
    assert_equal(TEST_ATIME, entry.atime)
  end

  def test_local_fields_picked_up_when_read_match_the_eagerly_read_ones
    ::Zip.preload_extra_fields = false
    deferred = ::Zip::File.new(TEST_ZIP)
    deferred.entries.select(&:file?).each { |entry| entry.get_input_stream(&:read) }

    ::Zip.preload_extra_fields = true
    eager = ::Zip::File.new(TEST_ZIP)

    eager.entries.select(&:file?).each do |eager_entry|
      entry = deferred.find_entry(eager_entry.name)

      assert_equal(eager_entry.extra.to_local_bin, entry.extra.to_local_bin, eager_entry.name)
      assert_equal(eager_entry.extra.to_c_dir_bin, entry.extra.to_c_dir_bin, eager_entry.name)
    end
  end

  def test_reading_an_entry_twice_does_not_merge_its_extra_field_twice
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.open_buffer(::File.binread(ODD_EXTRA_ZIP)).find_entry('Dockerfile')
    3.times { entry.get_input_stream(&:read) }

    ::Zip.preload_extra_fields = true
    eager = ::Zip::File.open_buffer(::File.binread(ODD_EXTRA_ZIP)).find_entry('Dockerfile')

    assert_equal(eager.extra.to_local_bin, entry.extra.to_local_bin)
  end

  def test_reading_an_entry_from_a_buffer_picks_up_its_local_fields
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.open_buffer(::File.binread(TEST_ZIP)).find_entry('file1')
    entry.get_input_stream(&:read)

    assert_equal(500, entry.extra[:iunix].uid)
  end

  def test_writing_an_archive_fetches_the_local_fields_it_needs
    ::Zip.preload_extra_fields = false
    zip_file = ::Zip::File.open_buffer(::File.binread(TEST_ZIP))
    zip_file.comment = 'Force a rewrite.'
    buffer = zip_file.write_buffer(::StringIO.new(+''))

    ::Zip.preload_extra_fields = true
    written = ::Zip::File.open_buffer(buffer)

    assert_equal('Force a rewrite.', written.comment)
    assert_equal(::Zip::File.new(TEST_ZIP).read('file1'), written.read('file1'))
    assert_equal(500, written.find_entry('file1').extra[:iunix].uid)
    assert_equal(TEST_ATIME, written.find_entry('file1').atime)
  end

  def test_writing_an_archive_twice_does_not_merge_local_fields_twice
    ::Zip.preload_extra_fields = false
    zip_file = ::Zip::File.open_buffer(::File.binread(ODD_EXTRA_ZIP))
    zip_file.comment = 'Force a rewrite.'
    zip_file.write_buffer(::StringIO.new(+''))
    buffer = zip_file.write_buffer(::StringIO.new(+''))

    ::Zip.preload_extra_fields = true
    expected = ::Zip::File.open_buffer(::File.binread(ODD_EXTRA_ZIP)).find_entry('Dockerfile')
    written = ::Zip::File.open_buffer(buffer).find_entry('Dockerfile')

    assert_equal(expected.extra.to_local_bin, written.extra.to_local_bin)
  end

  def test_a_written_archive_is_identical_whether_or_not_preloading_is_on
    FIXTURES.each do |fixture|
      written = PRELOAD_SETTINGS.map do |preload|
        ::Zip.preload_extra_fields = preload
        zip_file = ::Zip::File.open_buffer(::File.binread(fixture))
        zip_file.comment = 'Force a rewrite.'
        zip_file.write_buffer(::StringIO.new(+'')).string
      end

      assert_equal(written.first, written.last, fixture)
    end
  end

  def test_a_written_local_header_keeps_the_whole_unix_record
    ::Zip.preload_extra_fields = false
    zip_file = ::Zip::File.open_buffer(::File.binread(TEST_ZIP))
    zip_file.comment = 'Force a rewrite.'
    written = zip_file.write_buffer(::StringIO.new(+'')).string

    entry = ::Zip::File.open_buffer(written).find_entry('file1')
    io = ::StringIO.new(written)
    io.seek(entry.local_header_offset)
    local = ::Zip::Entry.read_local_entry(io)

    assert_equal(500, local.extra[:iunix].uid)
    assert_equal(500, local.extra[:iunix].gid)
    assert_equal(8, local.extra[:iunix].to_local_bin.bytesize)
  end

  def test_changing_an_entrys_owner_survives_a_rewrite
    ::Zip.preload_extra_fields = false
    zip_file = ::Zip::File.open_buffer(::File.binread(TEST_ZIP))
    zip_file.file.chown(1234, 5678, 'file1')
    zip_file.comment = 'Force a rewrite.'
    buffer = zip_file.write_buffer(::StringIO.new(+''))

    ::Zip.preload_extra_fields = true
    entry = ::Zip::File.open_buffer(buffer).find_entry('file1')

    assert_equal(1234, entry.extra[:iunix].uid)
    assert_equal(5678, entry.extra[:iunix].gid)
  end

  def test_rewriting_a_buffer_in_place_does_not_raise
    ::Zip.preload_extra_fields = false
    buffer = ::StringIO.new(::File.binread('test/data/local_extra_field.zip'))

    ::Zip::File.open_buffer(buffer) { |zip_file| zip_file.comment = 'Force a rewrite.' }
  end

  def test_copying_an_entry_repeatedly_does_not_grow_its_extra_field
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.open('test/data/zipWithStoredCompression.zip').entries.first

    sizes = Array.new(3) do
      ::Zip::OutputStream.write_buffer(::StringIO.new(+'')) do |zos|
        zos.copy_raw_entry(entry)
      end.string.bytesize
    end

    assert_equal([sizes.first] * 3, sizes)
  end

  def test_copying_an_entry_twice_into_one_stream_keeps_the_header_size
    ::Zip.allow_duplicate_entry_names = true
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.open('test/data/zipWithStoredCompression.zip').entries.first

    buffer = ::Zip::OutputStream.write_buffer(::StringIO.new(+'')) do |zos|
      zos.copy_raw_entry(entry)
      zos.copy_raw_entry(entry)
    end

    assert_equal(2, ::Zip::File.open_buffer(buffer).size)
  end

  def test_filesystem_stat_reports_the_owner_without_preloading
    ::Zip.preload_extra_fields = false

    ::Zip::File.open(TEST_ZIP) do |zip_file|
      assert_equal(500, zip_file.file.stat('file1').uid)
      assert_equal(500, zip_file.file.stat('file1').gid)
    end
  end

  def test_an_archive_rubyzip_wrote_can_be_rewritten_again
    PRELOAD_SETTINGS.each do |preload|
      ::Zip.preload_extra_fields = true
      first = ::Zip::File.open_buffer(::File.binread('test/data/zip64-sample.zip'))
      first.comment = 'First rewrite.'
      once = first.write_buffer(::StringIO.new(+'')).string

      ::Zip.preload_extra_fields = preload
      second = ::Zip::File.open_buffer(once.dup)
      second.comment = 'Second rewrite.'
      twice = second.write_buffer(::StringIO.new(+'')).string

      assert_equal('Second rewrite.', ::Zip::File.open_buffer(twice).comment)
    end
  end

  def test_copying_something_that_is_not_an_entry_is_still_rejected
    ::Zip.preload_extra_fields = false

    assert_raises(::Zip::Error) do
      ::Zip::OutputStream.write_buffer(::StringIO.new(+'')) do |zos|
        zos.copy_raw_entry('not an entry')
      end
    end
  end

  def test_setting_a_timestamp_before_the_fields_arrive_is_not_undone
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.open_buffer(::File.binread(TEST_ZIP)).find_entry('file1')
    entry.ctime = ::Zip::DOSTime.at(1_600_000_000)

    entry.load_local_extra_field

    assert_equal(::Zip::DOSTime.at(1_600_000_000), entry.ctime)
    assert_equal(::Zip::ExtraField::UniversalTime::CTIME_MASK,
                 entry.extra[:universaltime].flag & ::Zip::ExtraField::UniversalTime::CTIME_MASK)
  end

  def test_a_copied_entry_keeps_the_extra_field_preloading_would_have_given_it
    ::Zip.preload_extra_fields = true
    expected = copy_first_entry_of(TEST_ZIP)

    ::Zip.preload_extra_fields = false

    assert_equal(expected, copy_first_entry_of(TEST_ZIP))
  end

  def test_reading_an_entry_repeatedly_while_preloading_does_not_grow_it
    entry = ::Zip::File.new('test/data/osx-archive.zip').entries.find(&:file?)
    before = entry.extra.to_local_bin.bytesize
    3.times { entry.get_input_stream(&:read) }

    assert_equal(before, entry.extra.to_local_bin.bytesize)
  end

  def test_committing_a_file_fetches_the_local_fields_it_needs
    ::Dir.mktmpdir do |dir|
      path = ::File.join(dir, 'committed.zip')
      ::FileUtils.cp(TEST_ZIP, path)

      ::Zip.preload_extra_fields = false
      ::Zip::File.open(path) { |zip_file| zip_file.comment = 'Force a rewrite.' }

      ::Zip.preload_extra_fields = true

      assert_equal(500, ::Zip::File.new(path).find_entry('file1').extra[:iunix].uid)
    end
  end

  def test_filesystem_reports_times_without_preloading
    ::Zip.preload_extra_fields = false

    ::Zip::File.open(TEST_ZIP) do |zip_file|
      assert_equal(TEST_ATIME, zip_file.file.atime('file1'))
      assert_equal(TEST_ATIME, zip_file.file.stat('file1').atime)
    end
  end

  def test_every_extra_field_matches_what_preloading_reads
    FIXTURES.each do |fixture|
      ::Zip.preload_extra_fields = false
      read_later = ::Zip::File.new(fixture)
      read_later.entries.select(&:file?).each { |entry| entry.get_input_stream(&:read) }

      ::Zip.preload_extra_fields = true
      preloaded = ::Zip::File.new(fixture)

      preloaded.entries.select(&:file?).each do |expected|
        entry = read_later.find_entry(expected.name)
        where = "#{fixture}: #{expected.name}"

        assert_equal(expected.extra.keys.map(&:to_s).sort, entry.extra.keys.map(&:to_s).sort, where)
        assert_equal(expected.extra.to_local_bin, entry.extra.to_local_bin, where)
        assert_equal(expected.extra.to_c_dir_bin, entry.extra.to_c_dir_bin, where)
      end
    end
  end

  def test_entry_metadata_is_unaffected_by_turning_preloading_off
    FIXTURES.each do |fixture|
      preloaded = ::Zip::File.new(fixture).entries.sort_by(&:name)

      ::Zip.preload_extra_fields = false
      entries = ::Zip::File.new(fixture).entries.sort_by(&:name)

      METADATA.each do |field|
        assert_equal(preloaded.map(&field), entries.map(&field), "#{fixture}: #{field}")
      end

      ::Zip.reset!
    end
  end

  def test_ntfs_timestamps_are_picked_up_when_an_entry_is_read
    preloaded = ::Zip::File.new('test/data/ntfs.zip').entries.first

    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.new('test/data/ntfs.zip').entries.first
    entry.get_input_stream(&:read)

    assert_equal(preloaded.extra[:ntfs].mtime, entry.extra[:ntfs].mtime)
    assert_equal(preloaded.extra[:ntfs].atime, entry.extra[:ntfs].atime)
    assert_equal(preloaded.extra[:ntfs].ctime, entry.extra[:ntfs].ctime)
  end

  def test_an_aes_entry_can_still_be_decrypted_without_preloading
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.new('test/data/zip-aes-256.zip').entries.first

    assert(entry.aes?)

    decrypter = ::Zip::AESDecrypter.new('password', 3)

    assert_equal(
      ::File.binread('test/data/zip-aes-128.txt'),
      entry.get_input_stream(decrypter: decrypter, &:read)
    )
  end

  def test_zip64_sizes_are_correct_without_preloading
    preloaded = ::Zip::File.new('test/data/zip64-sample.zip').entries.first

    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.new('test/data/zip64-sample.zip').entries.first

    assert_equal(preloaded.size, entry.size)
    assert_equal(preloaded.compressed_size, entry.compressed_size)
    assert_equal(preloaded.get_input_stream(&:read), entry.get_input_stream(&:read))
  end

  def test_a_local_only_zip64_marker_is_picked_up_when_an_entry_is_read
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.new('test/data/zip64-sample.zip').entries.first

    refute(entry.zip64?)

    entry.get_input_stream(&:read)

    assert(entry.zip64?)
  end

  def test_extracting_an_entry_picks_up_its_local_fields
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.new(TEST_ZIP).find_entry('file1')

    ::Dir.mktmpdir do |dir|
      entry.extract('file1', destination_directory: dir)
    end

    assert_equal(500, entry.extra[:iunix].uid)
    assert_equal(TEST_ATIME, entry.atime)
  end

  def test_filesystem_stat_reports_the_owner_when_preloading
    ::Zip::File.open(TEST_ZIP) do |zip_file|
      assert_equal(500, zip_file.file.stat('file1').uid)
      assert_equal(500, zip_file.file.stat('file1').gid)
    end
  end

  def test_entry_contents_are_unaffected_by_turning_preloading_off
    expected = ::Zip::File.new(TEST_ZIP).read('file1')

    ::Zip.preload_extra_fields = false

    assert_equal(expected, ::Zip::File.new(TEST_ZIP).read('file1'))
  end
end
