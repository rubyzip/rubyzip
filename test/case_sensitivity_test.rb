require 'test_helper'

class ZipCaseSensitivityTest < MiniTest::Test
  include CommonZipFileFixture

  SRC_FILES = [['test/data/file1.txt', 'testfile.rb'],
               ['test/data/file2.txt', 'testFILE.rb']]

  def teardown
    ::Zip.case_insensitive_match = false
  end

  # Ensure that everything functions normally when +case_insensitive_match = false+
  def test_add_case_sensitive
    ::Zip.case_insensitive_match = false

    SRC_FILES.each { |fn, _en| assert(::File.exist?(fn)) }
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)

    SRC_FILES.each { |fn, en| zf.add(en, fn) }
    zf.close

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    assert_equal(SRC_FILES.size, zf_read.entries.length)
    SRC_FILES.each_with_index do |a, i|
      assert_equal(a.last, zf_read.entries[i].name)
      AssertEntry.assert_contents(a.first,
                                  zf_read.get_input_stream(a.last, &:read))
    end
  end

  # Ensure that names are treated case insensitively when adding files and +case_insensitive_match = false+
  def test_add_case_insensitive
    ::Zip.case_insensitive_match = true

    SRC_FILES.each { |fn, _en| assert(::File.exist?(fn)) }
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)

    assert_raises Zip::EntryExistsError do
      SRC_FILES.each { |fn, en| zf.add(en, fn) }
    end
  end

  # Ensure that names are treated case insensitively when reading files and +case_insensitive_match = true+
  def test_add_case_sensitive_read_case_insensitive
    ::Zip.case_insensitive_match = false

    SRC_FILES.each { |fn, _en| assert(::File.exist?(fn)) }
    zf = ::Zip::File.new(EMPTY_FILENAME, ::Zip::File::CREATE)

    SRC_FILES.each { |fn, en| zf.add(en, fn) }
    zf.close

    ::Zip.case_insensitive_match = true

    zf_read = ::Zip::File.new(EMPTY_FILENAME)
    assert_equal(SRC_FILES.collect { |_fn, en| en.downcase }.uniq.size, zf_read.entries.length)
    assert_equal(SRC_FILES.last.last.downcase, zf_read.entries.first.name.downcase)
    AssertEntry.assert_contents(
      SRC_FILES.last.first, zf_read.get_input_stream(SRC_FILES.last.last, &:read)
    )
  end

  private

  def assert_contains(zip_file, entry_name, filename = entry_name)
    refute_nil(
      zip_file.entries.detect { |e| e.name == entry_name },
      "entry #{entry_name} not in #{zip_file.entries.join(', ')} in zip file #{zip_file}"
    )
    assert_entry_contents(zip_file, entry_name, filename) if File.exist?(filename)
  end
end
