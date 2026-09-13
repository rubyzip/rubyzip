# frozen_string_literal: true

require_relative 'test_helper'

class ZipFileExtractAllTest < Minitest::Test
  SRC_DIR = 'test/data/generated/extract_all_src'
  ZIP_PATH = 'test/data/generated/extract_all.zip'
  DEST_DIR = 'test/data/generated/extract_all_dest'
  NO_DIRS_ZIP = 'test/data/generated/extract_all_no_dirs.zip'
  SYMLINK_ZIP = 'test/data/path_traversal/jwilk/dirsymlink.zip'

  def setup
    FileUtils.rm_rf(SRC_DIR)
    FileUtils.rm_rf(DEST_DIR)
    FileUtils.rm_f(ZIP_PATH)
    FileUtils.rm_f(NO_DIRS_ZIP)

    FileUtils.mkdir_p(::File.join(SRC_DIR, 'subdir'))
    FileUtils.mkdir_p(::File.join(SRC_DIR, 'empty_subdir'))
    ::File.write(::File.join(SRC_DIR, 'top.txt'), 'top level file')
    ::File.write(::File.join(SRC_DIR, 'subdir', 'nested.txt'), 'nested file')

    Zip::File.open(ZIP_PATH, create: true) { |zf| zf.add_recursive(SRC_DIR) }
  end

  def teardown
    Zip.reset!
  end

  def test_extract_all_round_trips_a_tree
    Zip::File.open(ZIP_PATH) { |zf| zf.extract_all(DEST_DIR) }

    assert_equal 'top level file', ::File.read(::File.join(DEST_DIR, 'top.txt'))
    assert_equal 'nested file', ::File.read(::File.join(DEST_DIR, 'subdir', 'nested.txt'))
    assert ::File.directory?(::File.join(DEST_DIR, 'empty_subdir'))
  end

  def test_extract_all_class_method
    Zip::File.extract_all(ZIP_PATH, DEST_DIR)

    assert_equal 'top level file', ::File.read(::File.join(DEST_DIR, 'top.txt'))
    assert_equal 'nested file', ::File.read(::File.join(DEST_DIR, 'subdir', 'nested.txt'))
    assert ::File.directory?(::File.join(DEST_DIR, 'empty_subdir'))
  end

  def test_extract_all_creates_missing_intermediate_directories
    # A hand-built archive with only file entries and nested paths - no
    # explicit directory entries at all.
    Zip::OutputStream.open(NO_DIRS_ZIP) do |out|
      out.put_next_entry('a/b/c/deep.txt')
      out.write 'deep content'
    end

    Zip::File.open(NO_DIRS_ZIP) { |zf| zf.extract_all(DEST_DIR) }

    assert_equal 'deep content', ::File.read(::File.join(DEST_DIR, 'a', 'b', 'c', 'deep.txt'))
  end

  def test_extract_all_skips_symlinks
    out = assert_output('', /WARNING: skipped symlink '.*tmp'/) do
      Zip::File.open(SYMLINK_ZIP) { |zf| zf.extract_all(DEST_DIR) }
    end
    refute_nil out

    refute ::File.symlink?(::File.join(DEST_DIR, 'tmp'))
    assert ::File.directory?(::File.join(DEST_DIR, 'tmp'))
    assert ::File.exist?(::File.join(DEST_DIR, 'tmp', 'moo'))
  end

  def test_extract_all_exists_raises_by_default
    FileUtils.mkdir_p(DEST_DIR)
    ::File.write(::File.join(DEST_DIR, 'top.txt'), 'pre-existing')

    assert_raises(Zip::DestinationExistsError) do
      Zip::File.open(ZIP_PATH) { |zf| zf.extract_all(DEST_DIR) }
    end
  end

  def test_extract_all_exists_overwrite_via_block
    FileUtils.mkdir_p(DEST_DIR)
    ::File.write(::File.join(DEST_DIR, 'top.txt'), 'pre-existing')

    called = false
    Zip::File.open(ZIP_PATH) do |zf|
      zf.extract_all(DEST_DIR) do
        called = true
        true
      end
    end

    assert called
    assert_equal 'top level file', ::File.read(::File.join(DEST_DIR, 'top.txt'))
  end
end
