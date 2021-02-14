require 'test_helper'

class EncryptionTest < MiniTest::Test
  ENCRYPT_ZIP_TEST_FILE = 'test/data/zipWithEncryption.zip'
  INPUT_FILE1 = 'test/data/file1.txt'

  def setup
    Zip.default_compression = ::Zlib::DEFAULT_COMPRESSION
  end

  def teardown
    Zip.reset!
  end

  def test_encrypt
    content = File.open(INPUT_FILE1, 'r').read
    test_filename = 'top_secret_file.txt'

    password = 'swordfish'

    encrypted_zip = Zip::OutputStream.write_buffer(::StringIO.new(''), Zip::TraditionalEncrypter.new(password)) do |out|
      out.put_next_entry(test_filename)
      out.write content
    end

    Zip::InputStream.open(encrypted_zip, 0, Zip::TraditionalDecrypter.new(password)) do |zis|
      entry = zis.get_next_entry
      assert_equal test_filename, entry.name
      assert_equal 1327, entry.size
      assert_equal content, zis.read
    end

    assert_raises(Zip::DecompressionError) do
      Zip::InputStream.open(encrypted_zip, 0, Zip::TraditionalDecrypter.new(password + 'wrong')) do |zis|
        zis.get_next_entry
        assert_equal content, zis.read
      end
    end
  end

  def test_decrypt
    Zip::InputStream.open(ENCRYPT_ZIP_TEST_FILE, 0, Zip::TraditionalDecrypter.new('password')) do |zis|
      entry = zis.get_next_entry
      assert_equal 'file1.txt', entry.name
      assert_equal 1327, entry.size
      assert_equal ::File.open(INPUT_FILE1, 'r').read, zis.read
    end
  end
end
