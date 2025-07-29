# frozen_string_literal: true

require_relative 'test_helper'

class Bzip2SupportTest < Minitest::Test
  BZIP2_ZIP_TEST_FILE = 'test/data/zipWithBzip2Compression.zip'

  def test_read
    Zip::InputStream.open(BZIP2_ZIP_TEST_FILE) do |zis|
      error = assert_raises(Zip::CompressionMethodError) do
        zis.get_next_entry
      end

      assert_equal(12, error.compression_method)
      assert_match(/BZIP2/, error.message)
    end
  end
end
