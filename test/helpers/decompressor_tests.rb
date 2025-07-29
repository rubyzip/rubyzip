# frozen_string_literal: true

module DecompressorTests
  # expects @ref_text, @ref_lines and @decompressor

  TEST_FILE = 'test/data/file1.txt'

  def setup
    @ref_text = ''
    File.open(TEST_FILE, 'rb') { |f| @ref_text = f.read }
    @ref_lines = @ref_text.split($INPUT_RECORD_SEPARATOR)
  end

  def test_read_everything
    assert_equal(@ref_text, @decompressor.read)
  end

  def test_read_in_chunks
    size = 5
    while (chunk = @decompressor.read(size))
      assert_equal(@ref_text.slice!(0, size), chunk)
    end
    assert_equal(0, @ref_text.size)
  end
end
