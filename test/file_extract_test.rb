# frozen_string_literal: true

require 'fileutils'

require 'test_helper'
require_relative 'helpers/assert_entry'
require_relative 'helpers/common_zipfile_fixtures'

class ZipFileExtractTest < Minitest::Test
  include CommonZipFileFixture

  EXTRACTED_FILENAME = 'test/data/generated/extEntry'
  EXTRACTED_FILENAME_ABS = ::File.absolute_path(EXTRACTED_FILENAME)
  ENTRY_TO_EXTRACT, *REMAINING_ENTRIES = TEST_ZIP.entry_names.reverse

  def setup
    super
    FileUtils.rm_f(EXTRACTED_FILENAME)
  end

  def teardown
    ::Zip.reset!
  end

  def test_extract
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      zf.extract(ENTRY_TO_EXTRACT, EXTRACTED_FILENAME)

      assert(File.exist?(EXTRACTED_FILENAME))
      AssertEntry.assert_contents(EXTRACTED_FILENAME,
                                  zf.get_input_stream(ENTRY_TO_EXTRACT, &:read))

      ::File.unlink(EXTRACTED_FILENAME)

      entry = zf.get_entry(ENTRY_TO_EXTRACT)
      entry.extract(EXTRACTED_FILENAME)

      assert(File.exist?(EXTRACTED_FILENAME))
      AssertEntry.assert_contents(EXTRACTED_FILENAME,
                                  entry.get_input_stream(&:read))
    end
  end

  def test_extract_exists
    text = 'written text'
    ::File.write(EXTRACTED_FILENAME, text)

    assert_raises(::Zip::DestinationExistsError) do
      ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
        zf.extract(zf.entries.first, EXTRACTED_FILENAME)
      end
    end

    File.open(EXTRACTED_FILENAME, 'r') do |f|
      assert_equal(text, f.read)
    end
  end

  def test_extract_exists_overwrite
    text = 'written text'
    ::File.write(EXTRACTED_FILENAME, text)

    called_correctly = false
    ::Zip::File.open(TEST_ZIP.zip_name) do |zf|
      zf.extract(zf.entries.first, EXTRACTED_FILENAME) do |entry, extract_loc|
        called_correctly = zf.entries.first == entry &&
                           extract_loc == EXTRACTED_FILENAME_ABS
        true
      end
    end

    assert(called_correctly)
    ::File.open(EXTRACTED_FILENAME, 'r') do |f|
      assert(text != f.read)
    end
  end

  def test_extract_non_entry
    zf = ::Zip::File.new(TEST_ZIP.zip_name)
    assert_raises(Errno::ENOENT) { zf.extract('nonExistingEntry', 'nonExistingEntry') }
  ensure
    zf.close if zf
  end

  def test_extract_another_non_entry
    out_file = 'outfile'
    assert_raises(Errno::ENOENT) do
      zf = ::Zip::File.new(TEST_ZIP.zip_name)
      non_entry = 'hotdog-diddelidoo'
      assert(!zf.entries.include?(non_entry))
      zf.extract(non_entry, out_file)
      zf.close
    end
    assert(!File.exist?(out_file))
  end

  def test_extract_incorrect_size
    Zip.write_zip64_support = false

    # The uncompressed size fields in the zip file cannot be trusted. This makes
    # it harder for callers to validate the sizes of the files they are
    # extracting, which can lead to denial of service. See also
    # https://en.wikipedia.org/wiki/Zip_bomb
    Dir.mktmpdir do |tmp|
      real_zip = File.join(tmp, 'real.zip')
      fake_zip = File.join(tmp, 'fake.zip')
      file_name = 'a'
      true_size = 500_000
      fake_size = 1

      ::Zip::File.open(real_zip, create: true) do |zf|
        zf.get_output_stream(file_name) do |os|
          os.write 'a' * true_size
        end
      end

      compressed_size = nil
      ::Zip::File.open(real_zip) do |zf|
        a_entry = zf.find_entry(file_name)
        compressed_size = a_entry.compressed_size
        assert_equal true_size, a_entry.size
      end

      true_size_bytes = [compressed_size, true_size, file_name.size].pack('VVv')
      fake_size_bytes = [compressed_size, fake_size, file_name.size].pack('VVv')

      data = File.binread(real_zip)
      assert data.include?(true_size_bytes)
      data.gsub! true_size_bytes, fake_size_bytes

      File.binwrite(fake_zip, data)

      Dir.chdir tmp do
        ::Zip::File.open(fake_zip) do |zf|
          a_entry = zf.find_entry(file_name)
          assert_equal fake_size, a_entry.size

          ::Zip.validate_entry_sizes = false
          assert_output('', /.+'a'.+1B.+/) do
            a_entry.extract
          end
          assert_equal true_size, File.size(file_name)
          FileUtils.rm file_name

          ::Zip.validate_entry_sizes = true
          error = assert_raises ::Zip::EntrySizeError do
            a_entry.extract
          end
          assert_equal(
            "Entry 'a' should be 1B, but is larger when inflated.",
            error.message
          )
        end
      end
    end
  end

  def test_extract_incorrect_size_zip64
    # The uncompressed size fields in the zip file cannot be trusted. This makes
    # it harder for callers to validate the sizes of the files they are
    # extracting, which can lead to denial of service. See also
    # https://en.wikipedia.org/wiki/Zip_bomb
    #
    # This version of the test ensures that fraudulent sizes in the ZIP64
    # extensions are caught.
    Dir.mktmpdir do |tmp|
      real_zip = File.join(tmp, 'real.zip')
      fake_zip = File.join(tmp, 'fake.zip')
      file_name = 'a'
      true_size = 500_000
      fake_size = 1

      ::Zip::File.open(real_zip, create: true) do |zf|
        zf.get_output_stream(file_name) do |os|
          os.write 'a' * true_size
        end
      end

      compressed_size = nil
      ::Zip::File.open(real_zip) do |zf|
        a_entry = zf.find_entry(file_name)
        compressed_size = a_entry.compressed_size
        assert_equal true_size, a_entry.size
      end

      true_size_bytes = [0x1, 16, true_size, compressed_size].pack('vvQ<Q<')
      fake_size_bytes = [0x1, 16, fake_size, compressed_size].pack('vvQ<Q<')

      data = File.binread(real_zip)
      assert data.include?(true_size_bytes)
      data.gsub! true_size_bytes, fake_size_bytes

      File.binwrite(fake_zip, data)

      Dir.chdir tmp do
        ::Zip::File.open(fake_zip) do |zf|
          a_entry = zf.find_entry(file_name)
          assert_equal fake_size, a_entry.size

          ::Zip.validate_entry_sizes = false
          assert_output('', /.+'a'.+1B.+/) do
            a_entry.extract
          end
          assert_equal true_size, File.size(file_name)
          FileUtils.rm file_name

          ::Zip.validate_entry_sizes = true
          error = assert_raises ::Zip::EntrySizeError do
            a_entry.extract
          end
          assert_equal(
            "Entry 'a' should be 1B, but is larger when inflated.",
            error.message
          )
        end
      end
    end
  end
end
