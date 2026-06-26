# frozen_string_literal: true

require_relative 'test_helper'

class EncryptionTest < Minitest::Test
  DATA_DIR = 'test/data'
  ENCRYPT_ZIP_TEST_FILE = 'zipWithEncryption.zip'
  AES_128_ZIP_TEST_FILE = 'zip-aes-128.zip'
  AES_256_ZIP_TEST_FILE = 'zip-aes-256.zip'
  AES_KEKA_ZIP_TEST_FILE = 'aes-keka.zip'
  INPUT_FILE1 = 'file1.txt'
  INPUT_FILE2 = 'file2.txt'
  INPUT_FILE3 = 'zip-aes-128.txt'
  INPUT_FILE4 = 'zip-aes-256.txt'
  INPUT_FILE5 = 'mimetype'

  def setup
    Zip.default_compression = ::Zlib::DEFAULT_COMPRESSION
  end

  def teardown
    Zip.reset!
  end

  def test_encrypt
    content = File.read("#{DATA_DIR}/#{INPUT_FILE1}")
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
      "#{DATA_DIR}/#{ENCRYPT_ZIP_TEST_FILE}",
      decrypter: Zip::TraditionalDecrypter.new('password')
    ) do |zis|
      entry = zis.get_next_entry
      assert_equal INPUT_FILE1, entry.name
      assert_equal 1_327, entry.size
      assert_equal ::File.read("#{DATA_DIR}/#{INPUT_FILE1}"), zis.read

      entry = zis.get_next_entry
      assert_equal INPUT_FILE2, entry.name
      assert_equal 41_234, entry.size
      assert_equal ::File.read("#{DATA_DIR}/#{INPUT_FILE2}"), zis.read
    end
  end

  def test_aes_128_decrypt
    Zip::InputStream.open(
      "#{DATA_DIR}/#{AES_128_ZIP_TEST_FILE}",
      decrypter: Zip::AESDecrypter.new('password', Zip::AESEncryption::STRENGTH_128_BIT)
    ) do |zis|
      entry = zis.get_next_entry
      assert_equal INPUT_FILE3, entry.name
      assert_equal 11, entry.size
      assert_equal ::File.read("#{DATA_DIR}/#{INPUT_FILE3}"), zis.read
    end
  end

  def test_aes_256_decrypt
    Zip::InputStream.open(
      "#{DATA_DIR}/#{AES_256_ZIP_TEST_FILE}",
      decrypter: Zip::AESDecrypter.new('password', Zip::AESEncryption::STRENGTH_256_BIT)
    ) do |zis|
      [INPUT_FILE3, INPUT_FILE4].each do |entry_name|
        entry = zis.get_next_entry
        assert entry
        assert_equal entry_name, entry.name
        assert entry.encrypted?
        assert_equal 11, entry.size

        file_stream = ::File.new("#{DATA_DIR}/#{INPUT_FILE3}")

        assert_equal file_stream.read(3), zis.read(3) # Ensure read with maxlen
        assert_equal file_stream.read(1), zis.read(1) # Ensure read after a read doesn't cause integrity issues
        file_stream.rewind
        zis.rewind
        assert_equal file_stream.read, zis.read # Ensure read after a rewind doesn't cause integrity issues
        file_stream.close
      end

      assert_nil zis.get_next_entry
    end
  end

  def test_aes_decrypt_keka
    Zip::InputStream.open(
      "#{DATA_DIR}/#{AES_KEKA_ZIP_TEST_FILE}",
      decrypter: Zip::AESDecrypter.new('swordfish', Zip::AESEncryption::STRENGTH_256_BIT)
    ) do |zis|
      entry = zis.get_next_entry
      assert_equal INPUT_FILE2, entry.name
      assert_equal 41_234, entry.size
      assert_equal ::File.read("#{DATA_DIR}/#{INPUT_FILE2}"), zis.read

      entry = zis.get_next_entry
      assert_equal INPUT_FILE5, entry.name
      assert_equal 20, entry.size
      assert_equal ::File.read("#{DATA_DIR}/#{INPUT_FILE5}"), zis.read
    end
  end
end
