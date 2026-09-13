# frozen_string_literal: true

require_relative 'test_helper'

class ZipFileAddRecursiveTest < Minitest::Test
  SRC_DIR = 'test/data/generated/add_recursive_src'
  OUT_ZIP = 'test/data/generated/add_recursive_out.zip'

  def setup
    FileUtils.rm_rf(SRC_DIR)
    FileUtils.rm_f(OUT_ZIP)

    FileUtils.mkdir_p(::File.join(SRC_DIR, 'subdir'))
    FileUtils.mkdir_p(::File.join(SRC_DIR, 'empty_subdir'))
    ::File.write(::File.join(SRC_DIR, 'top.txt'), 'top level file')
    ::File.write(::File.join(SRC_DIR, 'subdir', 'nested.txt'), 'nested file')
  end

  def teardown
    Zip.reset!
  end

  def test_add_recursive_adds_contents_not_the_directory_itself
    Zip::File.open(OUT_ZIP, create: true) do |zf|
      zf.add_recursive(SRC_DIR)
    end

    Zip::File.open(OUT_ZIP) do |zf|
      assert_equal(
        %w[top.txt subdir/ subdir/nested.txt empty_subdir/].sort,
        zf.entries.map(&:name).sort
      )
      assert_equal 'top level file', zf.read('top.txt')
      assert_equal 'nested file', zf.read('subdir/nested.txt')
      assert zf.find_entry('empty_subdir/').directory?
    end
  end

  def test_add_recursive_class_method
    Zip::File.add_recursive(OUT_ZIP, SRC_DIR)

    Zip::File.open(OUT_ZIP) do |zf|
      assert_equal(
        %w[top.txt subdir/ subdir/nested.txt empty_subdir/].sort,
        zf.entries.map(&:name).sort
      )
      assert_equal 'top level file', zf.read('top.txt')
      assert_equal 'nested file', zf.read('subdir/nested.txt')
      assert zf.find_entry('empty_subdir/').directory?
    end
  end

  def test_add_recursive_with_entry_prefix
    Zip::File.open(OUT_ZIP, create: true) do |zf|
      zf.add_recursive(SRC_DIR, prefix: 'assets')
    end

    Zip::File.open(OUT_ZIP) do |zf|
      assert_equal(
        %w[assets/top.txt assets/subdir/ assets/subdir/nested.txt assets/empty_subdir/].sort,
        zf.entries.map(&:name).sort
      )
    end
  end

  def test_add_recursive_respects_max_depth
    out = assert_output('', /WARNING: max_depth \(1\) reached, not descending into '.*subdir'/) do
      Zip::File.open(OUT_ZIP, create: true) do |zf|
        zf.add_recursive(SRC_DIR, max_depth: 1)
      end
    end
    refute_nil out

    Zip::File.open(OUT_ZIP) do |zf|
      names = zf.entries.map(&:name)
      assert_includes names, 'top.txt'
      assert_includes names, 'subdir/'
      assert_includes names, 'empty_subdir/'
      refute_includes names, 'subdir/nested.txt'
    end
  end

  def test_add_recursive_rejects_max_depth_below_one
    Zip::File.open(OUT_ZIP, create: true) do |zf|
      assert_raises(ArgumentError) { zf.add_recursive(SRC_DIR, max_depth: 0) }
    end
  end

  def test_add_recursive_raises_for_missing_directory
    Zip::File.open(OUT_ZIP, create: true) do |zf|
      assert_raises(Errno::ENOENT) { zf.add_recursive('test/data/generated/does_not_exist') }
    end
  end

  def test_add_recursive_conflict_raises_by_default
    Zip::File.open(OUT_ZIP, create: true) do |zf|
      zf.mkdir('top.txt')

      assert_raises(Zip::EntryExistsError) { zf.add_recursive(SRC_DIR) }
    end
  end

  def test_add_recursive_conflict_overridable_via_block
    Zip::File.open(OUT_ZIP, create: true) do |zf|
      zf.get_output_stream('top.txt') { |f| f.write 'old content' }

      called = false
      zf.add_recursive(SRC_DIR) do
        called = true
        true
      end

      assert called
      assert_equal 'top level file', zf.read('top.txt')
    end
  end

  def test_add_recursive_ignores_symlinks
    skip if Zip::RUNNING_ON_WINDOWS

    link_path = ::File.join(SRC_DIR, 'a_symlink')
    begin
      ::File.symlink('top.txt', link_path)
    rescue NotImplementedError, Errno::EPERM
      skip 'symlinks are not supported/permitted on this platform'
    end

    assert_output('', /WARNING: skipped symlink '.*a_symlink'/) do
      Zip::File.open(OUT_ZIP, create: true) do |zf|
        zf.add_recursive(SRC_DIR)
      end
    end

    Zip::File.open(OUT_ZIP) do |zf|
      refute_includes zf.entries.map(&:name), 'a_symlink'
    end
  end
end
