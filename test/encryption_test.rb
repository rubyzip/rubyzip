# frozen_string_literal: true

require 'test_helper'

class EncryptionTest < MiniTest::Test
  ENCRYPT_ZIP_TEST_FILE = 'test/data/zipWithEncryption.zip'
  AES_128_ZIP_TEST_FILE = 'test/data/zip-aes-128.zip'
  AES_256_ZIP_TEST_FILE = 'test/data/zip-aes-256.zip'
  INPUT_FILE1 = 'test/data/file1.txt'
  INPUT_FILE2 = 'test/data/file2.txt'
  INPUT_FILE3 = 'test/data/zip-aes-128.txt'
  INPUT_FILE4 = 'test/data/zip-aes-256.txt'

  def setup
    Zip.default_compression = ::Zlib::DEFAULT_COMPRESSION
  end

  def teardown
    Zip.reset!
  end

  def test_encrypt
    content = File.read(INPUT_FILE1)
    test_filename = 'top_secret_file.txt'

    password = 'swordfish'

    encrypted_zip = Zip::OutputStream.write_buffer(
      ::StringIO.new,
      encrypter: Zip::TraditionalEncrypter.new(password)
    ) do |out|
      out.put_next_entry(test_filename)
      out.write content
    end

    Zip::InputStream.open(
      encrypted_zip, decrypter: Zip::TraditionalDecrypter.new(password)
    ) do |zis|
      entry = zis.get_next_entry
      assert_equal test_filename, entry.name
      assert_equal 1_327, entry.size
      assert_equal content, zis.read
    end

    error = assert_raises(Zip::DecompressionError) do
      Zip::InputStream.open(
        encrypted_zip,
        decrypter: Zip::TraditionalDecrypter.new("#{password}wrong")
      ) do |zis|
        zis.get_next_entry
        assert_equal content, zis.read
      end
    end
    assert_match(/Zlib error \('.+'\) while inflating\./, error.message)
  end

  def test_decrypt
    Zip::InputStream.open(
      ENCRYPT_ZIP_TEST_FILE,
      decrypter: Zip::TraditionalDecrypter.new('password')
    ) do |zis|
      entry = zis.get_next_entry
      assert_equal 'file1.txt', entry.name
      assert_equal 1_327, entry.size
      assert_equal ::File.read(INPUT_FILE1), zis.read
      entry = zis.get_next_entry
      assert_equal 'file2.txt', entry.name
      assert_equal 41_234, entry.size
      assert_equal ::File.read(INPUT_FILE2), zis.read
    end
  end

  def test_aes_128_decrypt
    Zip::InputStream.open(
      AES_128_ZIP_TEST_FILE,
      decrypter: Zip::AESDecrypter.new('password', Zip::AESEncryption::STRENGTH_128_BIT)
    ) do |zis|
      entry = zis.get_next_entry
      assert_equal 'a', entry.name
      assert_equal 1, entry.size
      assert_equal ::File.read(INPUT_FILE3), zis.read
    end
  end

  def test_aes_256_decrypt
    Zip::InputStream.open(
      AES_256_ZIP_TEST_FILE,
      decrypter: Zip::AESDecrypter.new('password', Zip::AESEncryption::STRENGTH_256_BIT)
    ) do |zis|
      entry = zis.get_next_entry
      assert_equal 'a', entry.name
      assert_equal 0, entry.size
      assert_equal '', zis.read
      entry = zis.get_next_entry
      assert_equal 'b', entry.name
      assert_equal 1, entry.size
      assert_equal ::File.read(INPUT_FILE4), zis.read
    end
  end
end
