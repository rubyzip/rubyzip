# frozen_string_literal: true

require_relative 'test_helper'

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

  def test_an_archive_can_be_written_without_its_local_extra_fields
    ::Zip.preload_extra_fields = false
    zip_file = ::Zip::File.open_buffer(::File.binread(TEST_ZIP))
    zip_file.comment = 'Force a rewrite.'
    buffer = zip_file.write_buffer(::StringIO.new(+''))

    ::Zip.preload_extra_fields = true
    written = ::Zip::File.open_buffer(buffer)

    assert_equal('Force a rewrite.', written.comment)
    assert_equal(::Zip::File.new(TEST_ZIP).read('file1'), written.read('file1'))

    assert_nil(written.find_entry('file1').extra[:iunix].uid)
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

  def test_filesystem_stat_has_no_owner_without_preloading
    ::Zip.preload_extra_fields = false

    ::Zip::File.open(TEST_ZIP) do |zip_file|
      assert_equal(0, zip_file.file.stat('file1').uid)
      assert_equal(0, zip_file.file.stat('file1').gid)
    end
  end

  def test_an_unread_unix_field_round_trips_as_an_empty_record
    ::Zip.preload_extra_fields = false
    entry = ::Zip::File.new(TEST_ZIP).find_entry('file1')

    round_tripped = ::Zip::ExtraField.new(entry.extra.to_local_bin, local: true)

    assert_equal(entry.extra.keys.map(&:to_s).sort, round_tripped.keys.map(&:to_s).sort)
    assert_nil(round_tripped[:iunix].uid)
  end

  def test_entry_contents_are_unaffected_by_turning_preloading_off
    expected = ::Zip::File.new(TEST_ZIP).read('file1')

    ::Zip.preload_extra_fields = false

    assert_equal(expected, ::Zip::File.new(TEST_ZIP).read('file1'))
  end
end
