require 'test_helper'
require 'zip/filesystem'

class ZipFsDirIteratorTest < MiniTest::Test
  FILENAME_ARRAY = %w[f1 f2 f3 f4 f5 f6]

  def setup
    @dir_iter = ::Zip::FileSystem::ZipFsDirIterator.new(FILENAME_ARRAY)
  end

  def test_close
    @dir_iter.close
    assert_raises(IOError, 'closed directory') do
      @dir_iter.each { |e| p e }
    end
    assert_raises(IOError, 'closed directory') do
      @dir_iter.read
    end
    assert_raises(IOError, 'closed directory') do
      @dir_iter.rewind
    end
    assert_raises(IOError, 'closed directory') do
      @dir_iter.seek(0)
    end
    assert_raises(IOError, 'closed directory') do
      @dir_iter.tell
    end
  end

  def test_each
    # Tested through Enumerable.entries
    assert_equal(FILENAME_ARRAY, @dir_iter.entries)
  end

  def test_read
    FILENAME_ARRAY.size.times do |i|
      assert_equal(FILENAME_ARRAY[i], @dir_iter.read)
    end
  end

  def test_rewind
    @dir_iter.read
    @dir_iter.read
    assert_equal(FILENAME_ARRAY[2], @dir_iter.read)
    @dir_iter.rewind
    assert_equal(FILENAME_ARRAY[0], @dir_iter.read)
  end

  def test_tell_seek
    @dir_iter.read
    @dir_iter.read
    pos = @dir_iter.tell
    value = @dir_iter.read
    @dir_iter.read
    @dir_iter.seek(pos)
    assert_equal(value, @dir_iter.read)
  end
end
