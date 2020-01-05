require 'test_helper'

class Bzip2SupportTest < MiniTest::Test
  BZIP2_ZIP_TEST_FILE = 'test/data/zipWithBzip2Compression.zip'

  def test_read
    Zip::InputStream.open(BZIP2_ZIP_TEST_FILE) do |zis|
      assert_raises(Zip::CompressionMethodError) { zis.get_next_entry }
    end
  end
end
