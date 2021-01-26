require 'test_helper'

class BasicZipFileTest < MiniTest::Test
  include AssertEntry

  def setup
    @zip_file = ::Zip::File.new(TestZipFile::TEST_ZIP2.zip_name)
  end

  def test_entries
    expected_entry_names = TestZipFile::TEST_ZIP2.entry_names
    actual_entry_names = @zip_file.entries.entries.map(&:name)
    assert_equal(expected_entry_names.sort, actual_entry_names.sort)
  end

  def test_each
    expected_entry_names = TestZipFile::TEST_ZIP2.entry_names
    actual_entry_names = []
    @zip_file.each { |entry| actual_entry_names << entry.name }
    assert_equal(expected_entry_names.sort, actual_entry_names.sort)
  end

  def test_foreach
    expected_entry_names = TestZipFile::TEST_ZIP2.entry_names
    actual_entry_names = []
    ::Zip::File.foreach(TestZipFile::TEST_ZIP2.zip_name) { |entry| actual_entry_names << entry.name }
    assert_equal(expected_entry_names.sort, actual_entry_names.sort)
  end

  def test_get_input_stream
    expected_entry_names = TestZipFile::TEST_ZIP2.entry_names
    actual_entry_names = []

    @zip_file.each do |entry|
      actual_entry_names << entry.name
      assert_entry(entry.name, @zip_file.get_input_stream(entry), entry.name)
    end

    assert_equal(expected_entry_names.sort, actual_entry_names.sort)
  end

  def test_get_input_stream_block
    name = @zip_file.entries.first.name
    @zip_file.get_input_stream(name) do |zis|
      assert_entry_contents_for_stream(name, zis, name)
    end
  end
end
