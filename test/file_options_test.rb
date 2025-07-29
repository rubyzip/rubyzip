# frozen_string_literal: true

require 'fileutils'

require_relative 'test_helper'

class FileOptionsTest < Minitest::Test
  ZIPPATH = ::File.join(Dir.tmpdir, 'options.zip').freeze
  TXTPATH = ::File.expand_path(::File.join('data', 'file1.txt'), __dir__).freeze
  TXTPATH_600 = ::File.join(Dir.tmpdir, 'file1.600.txt').freeze
  TXTPATH_755 = ::File.join(Dir.tmpdir, 'file1.755.txt').freeze
  ENTRY_1 = 'entry_1.txt'
  ENTRY_2 = 'entry_2.txt'
  ENTRY_3 = 'entry_3.txt'
  EXTRACT_1 = 'extracted_1.txt'
  EXTRACT_2 = 'extracted_2.txt'
  EXTRACT_3 = 'extracted_3.txt'
  EXTPATH_1 = ::File.join(Dir.tmpdir, EXTRACT_1).freeze
  EXTPATH_2 = ::File.join(Dir.tmpdir, EXTRACT_2).freeze
  EXTPATH_3 = ::File.join(Dir.tmpdir, EXTRACT_3).freeze

  def teardown
    FileUtils.rm_f(ZIPPATH)
    FileUtils.rm_f(EXTPATH_1)
    FileUtils.rm_f(EXTPATH_2)
    FileUtils.rm_f(EXTPATH_3)
    FileUtils.rm_f(TXTPATH_600)
    FileUtils.rm_f(TXTPATH_755)
  end

  def test_restore_permissions_true
    # Copy and set up files with different permissions.
    ::FileUtils.cp(TXTPATH, TXTPATH_600)
    ::File.chmod(0o600, TXTPATH_600)
    ::FileUtils.cp(TXTPATH, TXTPATH_755)
    ::File.chmod(0o755, TXTPATH_755)

    ::Zip::File.open(ZIPPATH, create: true) do |zip|
      zip.add(ENTRY_1, TXTPATH)
      zip.add(ENTRY_2, TXTPATH_600)
      zip.add(ENTRY_3, TXTPATH_755)
    end

    ::Zip::File.open(ZIPPATH, restore_permissions: true) do |zip|
      zip.extract(ENTRY_1, EXTRACT_1, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_2, EXTRACT_2, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_3, EXTRACT_3, destination_directory: Dir.tmpdir)
    end

    assert_equal(::File.stat(TXTPATH).mode, ::File.stat(EXTPATH_1).mode)
    assert_equal(::File.stat(TXTPATH_600).mode, ::File.stat(EXTPATH_2).mode)
    assert_equal(::File.stat(TXTPATH_755).mode, ::File.stat(EXTPATH_3).mode)
  end

  def test_restore_permissions_false
    # Copy and set up files with different permissions.
    ::FileUtils.cp(TXTPATH, TXTPATH_600)
    ::File.chmod(0o600, TXTPATH_600)
    ::FileUtils.cp(TXTPATH, TXTPATH_755)
    ::File.chmod(0o755, TXTPATH_755)

    ::Zip::File.open(ZIPPATH, create: true) do |zip|
      zip.add(ENTRY_1, TXTPATH)
      zip.add(ENTRY_2, TXTPATH_600)
      zip.add(ENTRY_3, TXTPATH_755)
    end

    ::Zip::File.open(ZIPPATH, restore_permissions: false) do |zip|
      zip.extract(ENTRY_1, EXTRACT_1, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_2, EXTRACT_2, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_3, EXTRACT_3, destination_directory: Dir.tmpdir)
    end

    default_perms = (Zip::RUNNING_ON_WINDOWS ? 0o100_644 : 0o100_666) - ::File.umask
    assert_equal(default_perms, ::File.stat(EXTPATH_1).mode)
    assert_equal(default_perms, ::File.stat(EXTPATH_2).mode)
    assert_equal(default_perms, ::File.stat(EXTPATH_3).mode)
  end

  def test_restore_permissions_as_default
    # Copy and set up files with different permissions.
    ::FileUtils.cp(TXTPATH, TXTPATH_600)
    ::File.chmod(0o600, TXTPATH_600)
    ::FileUtils.cp(TXTPATH, TXTPATH_755)
    ::File.chmod(0o755, TXTPATH_755)

    ::Zip::File.open(ZIPPATH, create: true) do |zip|
      zip.add(ENTRY_1, TXTPATH)
      zip.add(ENTRY_2, TXTPATH_600)
      zip.add(ENTRY_3, TXTPATH_755)
    end

    ::Zip::File.open(ZIPPATH) do |zip|
      zip.extract(ENTRY_1, EXTRACT_1, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_2, EXTRACT_2, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_3, EXTRACT_3, destination_directory: Dir.tmpdir)
    end

    assert_equal(::File.stat(TXTPATH).mode, ::File.stat(EXTPATH_1).mode)
    assert_equal(::File.stat(TXTPATH_600).mode, ::File.stat(EXTPATH_2).mode)
    assert_equal(::File.stat(TXTPATH_755).mode, ::File.stat(EXTPATH_3).mode)
  end

  def test_restore_times_true
    ::Zip::File.open(ZIPPATH, create: true) do |zip|
      zip.add(ENTRY_1, TXTPATH)
      zip.add_stored(ENTRY_2, TXTPATH)
    end

    ::Zip::File.open(ZIPPATH, restore_times: true) do |zip|
      zip.extract(ENTRY_1, EXTRACT_1, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_2, EXTRACT_2, destination_directory: Dir.tmpdir)
    end

    assert_time_equal(::File.mtime(TXTPATH), ::File.mtime(EXTPATH_1))
    assert_time_equal(::File.mtime(TXTPATH), ::File.mtime(EXTPATH_2))
  end

  def test_restore_times_false
    ::Zip::File.open(ZIPPATH, create: true) do |zip|
      zip.add(ENTRY_1, TXTPATH)
      zip.add_stored(ENTRY_2, TXTPATH)
    end

    ::Zip::File.open(ZIPPATH, restore_times: false) do |zip|
      zip.extract(ENTRY_1, EXTRACT_1, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_2, EXTRACT_2, destination_directory: Dir.tmpdir)
    end

    assert_time_equal(::Time.now, ::File.mtime(EXTPATH_1))
    assert_time_equal(::Time.now, ::File.mtime(EXTPATH_2))
  end

  def test_restore_times_true_as_default
    ::Zip::File.open(ZIPPATH, create: true) do |zip|
      zip.add(ENTRY_1, TXTPATH)
      zip.add_stored(ENTRY_2, TXTPATH)
    end

    ::Zip::File.open(ZIPPATH) do |zip|
      zip.extract(ENTRY_1, EXTRACT_1, destination_directory: Dir.tmpdir)
      zip.extract(ENTRY_2, EXTRACT_2, destination_directory: Dir.tmpdir)
    end

    assert_time_equal(::File.mtime(TXTPATH), ::File.mtime(EXTPATH_1))
    assert_time_equal(::File.mtime(TXTPATH), ::File.mtime(EXTPATH_2))
  end

  def test_get_find_consistency
    testzip = ::File.expand_path(::File.join('data', 'globTest.zip'), __dir__)
    Dir.mktmpdir do |tmp|
      file_f = ::File.expand_path('f_test.txt', tmp)
      file_g = ::File.expand_path('g_test.txt', tmp)

      ::Zip::File.open(testzip) do |zip|
        e1 = zip.find_entry('globTest/food.txt')
        e1.extract('f_test.txt', destination_directory: tmp)
        e2 = zip.get_entry('globTest/food.txt')
        e2.extract('g_test.txt', destination_directory: tmp)
      end

      assert_time_equal(::File.mtime(file_f), ::File.mtime(file_g))
    end
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
