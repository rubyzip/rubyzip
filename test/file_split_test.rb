# frozen_string_literal: true

require 'test_helper'

class ZipFileSplitTest < MiniTest::Test
  TEST_ZIP = TestZipFile::TEST_ZIP2.clone
  TEST_ZIP.zip_name = 'large_zip_file.zip'
  TEST_ZIP_FIRST_SEGMENT = 'large_zip_file.zip.001'
  EXTRACTED_FILENAME = 'test/data/generated/extEntrySplit'
  UNSPLITTED_FILENAME = 'test/data/generated/unsplitted.zip'
  ENTRY_TO_EXTRACT = TEST_ZIP.entry_names.first

  def setup
    FileUtils.cp(TestZipFile::TEST_ZIP2.zip_name, TEST_ZIP.zip_name)
  end

  def teardown
    File.delete(TEST_ZIP.zip_name)
    FileUtils.rm_f(UNSPLITTED_FILENAME)

    Dir["#{TEST_ZIP.zip_name}.*"].each do |zip_file_name|
      FileUtils.rm_f(zip_file_name)
    end
  end

  def test_split_method_respond
    assert_respond_to ::Zip::File, :split, 'Does not have split class method'
  end

  def test_split
    result = ::Zip::File.split(
      TEST_ZIP.zip_name, segment_size: 65_536, delete_original: false
    )

    return if result.nil?

    Dir["#{TEST_ZIP.zip_name}.*"].each_with_index do |zip_file_name, index|
      File.open(zip_file_name, 'rb') do |zip_file|
        zip_file.read([::Zip::SPLIT_FILE_SIGNATURE].pack('V').size) if index.zero?
        File.open(UNSPLITTED_FILENAME, 'ab') do |file|
          file << zip_file.read
        end
      end
    end

    ::Zip::File.open(UNSPLITTED_FILENAME) do |zf|
      zf.extract(ENTRY_TO_EXTRACT, EXTRACTED_FILENAME)

      assert(File.exist?(EXTRACTED_FILENAME))
      AssertEntry.assert_contents(EXTRACTED_FILENAME,
                                  zf.get_input_stream(ENTRY_TO_EXTRACT, &:read))

      File.unlink(EXTRACTED_FILENAME)

      entry = zf.get_entry(ENTRY_TO_EXTRACT)
      entry.extract(EXTRACTED_FILENAME)

      assert(File.exist?(EXTRACTED_FILENAME))
      AssertEntry.assert_contents(EXTRACTED_FILENAME,
                                  entry.get_input_stream(&:read))
    end
  end

  def test_raise_error_on_open_split_zip
    ::Zip::File.split(TEST_ZIP.zip_name, segment_size: 65_536, delete_original: false)

    assert_raises(::Zip::SplitArchiveError) do
      ::Zip::InputStream.open(TEST_ZIP_FIRST_SEGMENT, &:get_next_entry)
    end
  end
end
