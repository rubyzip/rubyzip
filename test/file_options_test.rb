require 'test_helper'

class FileOptionsTest < MiniTest::Test
  ZIPPATH = ::File.join(Dir.tmpdir, 'options.zip').freeze
  TXTPATH = ::File.expand_path(::File.join('data', 'file1.txt'), __dir__).freeze
  EXTPATH_1 = ::File.join(Dir.tmpdir, 'extracted_1.txt').freeze
  EXTPATH_2 = ::File.join(Dir.tmpdir, 'extracted_2.txt').freeze
  ENTRY_1 = 'entry_1.txt'.freeze
  ENTRY_2 = 'entry_2.txt'.freeze

  def teardown
    ::File.unlink(ZIPPATH) if ::File.exist?(ZIPPATH)
    ::File.unlink(EXTPATH_1) if ::File.exist?(EXTPATH_1)
    ::File.unlink(EXTPATH_2) if ::File.exist?(EXTPATH_2)
  end

  def test_restore_times_true
    ::Zip::File.open(ZIPPATH, true) do |zip|
      zip.add(ENTRY_1, TXTPATH)
      zip.add_stored(ENTRY_2, TXTPATH)
    end

    ::Zip::File.open(ZIPPATH, false, restore_times: true) do |zip|
      zip.extract(ENTRY_1, EXTPATH_1)
      zip.extract(ENTRY_2, EXTPATH_2)
    end

    assert_time_equal(::File.mtime(TXTPATH), ::File.mtime(EXTPATH_1))
    assert_time_equal(::File.mtime(TXTPATH), ::File.mtime(EXTPATH_2))
  end

  def test_restore_times_false
    ::Zip::File.open(ZIPPATH, true) do |zip|
      zip.add(ENTRY_1, TXTPATH)
      zip.add_stored(ENTRY_2, TXTPATH)
    end

    ::Zip::File.open(ZIPPATH, false, restore_times: false) do |zip|
      zip.extract(ENTRY_1, EXTPATH_1)
      zip.extract(ENTRY_2, EXTPATH_2)
    end

    assert_time_equal(::Time.now, ::File.mtime(EXTPATH_1))
    assert_time_equal(::Time.now, ::File.mtime(EXTPATH_2))
  end

  private

  # Method to compare file times. DOS times only have 2 second accuracy.
  def assert_time_equal(expected, actual)
    assert_equal(expected.year, actual.year)
    assert_equal(expected.month, actual.month)
    assert_equal(expected.day, actual.day)
    assert_equal(expected.hour, actual.hour)
    assert_equal(expected.min, actual.min)
    assert_in_delta(expected.sec, actual.sec, 1)
  end
end
