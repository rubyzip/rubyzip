require 'test_helper'

class Bzip2SupportTest < MiniTest::Test
  BZIP2_ZIP_TEST_FILE = 'test/data/zipWithBzip2Compression.zip'
  ENCRYPTED_BZIP2_ZIP_TEST_FILE = 'test/data/zipWithBzip2CompressionAndEncryption.zip'
  INPUT_FILE1 = 'test/data/file1.txt'
  INPUT_FILE2 = 'test/data/file2.txt'

  def test_read
    Zip::InputStream.open(BZIP2_ZIP_TEST_FILE) do |zis|
      entry = zis.get_next_entry
      assert_equal 'file1.txt', entry.name
      assert_equal 1327, entry.size
      assert_equal open(INPUT_FILE1, 'r').read, zis.read
      entry = zis.get_next_entry
      assert_equal 'file2.txt', entry.name
      assert_equal 41234, entry.size
      assert_equal open(INPUT_FILE2, 'r').read, zis.read
    end
  end

  def test_encrypted_read
    Zip::InputStream.open(ENCRYPTED_BZIP2_ZIP_TEST_FILE, 0, Zip::TraditionalDecrypter.new('password')) do |zis|
      entry = zis.get_next_entry
      assert_equal 'file1.txt', entry.name
      assert_equal 1327, entry.size
      assert_equal open(INPUT_FILE1, 'r').read, zis.read
      entry = zis.get_next_entry
      assert_equal 'file2.txt', entry.name
      assert_equal 41234, entry.size
      assert_equal open(INPUT_FILE2, 'r').read, zis.read
    end
  end
end
