# frozen_string_literal: true

require_relative '../test_helper'
require 'securerandom'

class AESDecrypterTest < Minitest::Test
  def setup
    @decrypter256 = ::Zip::AESDecrypter.new('password', ::Zip::AESEncryption::STRENGTH_256_BIT)
    @decrypter128 = ::Zip::AESDecrypter.new('password', ::Zip::AESEncryption::STRENGTH_128_BIT)
  end

  def test_header_bytesize
    assert_equal 18, @decrypter256.header_bytesize
  end

  def test_gp_flags
    assert_equal 1, @decrypter256.gp_flags
  end

  def test_decrypt_aes256
    header = [125, 138, 163, 42, 19, 1, 155, 66, 203, 174, 183, 235, 197, 122, 232, 68, 252, 225].pack('C*')
    @decrypter256.reset!(header)
    assert_equal 'a', @decrypter256.decrypt([161].map(&:chr).join)
  end

  def test_decrypt_aes128
    header = [127, 254, 117, 113, 255, 209, 171, 131, 179, 106].pack('C*')
    @decrypter128.reset!(header)
    assert_equal [75, 4, 0].pack('C*'), @decrypter128.decrypt([34, 33, 106].map(&:chr).join)
  end

  def test_reset!
    header = [125, 138, 163, 42, 19, 1, 155, 66, 203, 174, 183, 235, 197, 122, 232, 68, 252, 225].pack('C*')
    @decrypter256.reset!(header)
    assert_equal 'a', @decrypter256.decrypt([161].map(&:chr).join)

    header = [118, 221, 166, 27, 165, 141, 24, 122, 227, 197, 52, 135, 222, 67, 221, 92, 231, 117].pack('C*')
    @decrypter256.reset!(header)
    assert_equal 'b', @decrypter256.decrypt([135].map(&:chr).join)
  end
end

class AESEncrypterTest < Minitest::Test
  STRENGTHS = [
    Zip::AESEncryption::STRENGTH_128_BIT,
    Zip::AESEncryption::STRENGTH_192_BIT,
    Zip::AESEncryption::STRENGTH_256_BIT
  ].freeze

  def setup
    @password = 'password'
  end

  def test_header_bytesize
    encrypter = Zip::AESEncrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)
    encrypter.reset!
    assert_equal 18, encrypter.header_bytesize
    assert_equal 18, encrypter.header('ignored').bytesize
  end

  def test_gp_flags
    encrypter = Zip::AESEncrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)
    assert_equal 1, encrypter.gp_flags
  end

  def test_data_descriptor_and_crc_are_suppressed
    encrypter = Zip::AESEncrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)
    assert_equal '', encrypter.data_descriptor(12_345, 100, 100)
    assert_equal 0, encrypter.crc(12_345)
  end

  def test_reset_generates_a_fresh_salt_each_time
    encrypter = Zip::AESEncrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)

    encrypter.reset!
    first_header = encrypter.header('ignored')

    encrypter.reset!
    second_header = encrypter.header('ignored')

    refute_equal first_header, second_header
  end

  # `trailer` returns whatever ciphertext was still buffered (a final,
  # not-yet-block-aligned remainder) followed by the 10-byte authentication
  # code, since that's what `OutputStream` needs to be able to just append
  # it straight onto the output (see `Zip::OutputStream#finalize_current_entry`).
  # These tests split it back into its two parts.
  def split_trailer(trailer)
    auth_length = Zip::AESEncryption::AUTHENTICATION_CODE_LENGTH
    [trailer[0...-auth_length], trailer[-auth_length..]]
  end

  def test_encrypt_decrypt_round_trip
    plaintext = 'the quick brown fox jumps over the lazy dog' * 100

    STRENGTHS.each do |strength|
      encrypter = Zip::AESEncrypter.new(@password, strength)
      encrypter.reset!
      header = encrypter.header('ignored')
      ciphertext = encrypter.encrypt(plaintext)
      leftover, auth_code = split_trailer(encrypter.trailer)

      decrypter = Zip::AESDecrypter.new(@password, strength)
      decrypter.reset!(header)
      decrypted = decrypter.decrypt(ciphertext + leftover)
      decrypter.check_integrity!(StringIO.new(auth_code))

      assert_equal plaintext, decrypted
    end
  end

  # Chunk sizes are deliberately *not* multiples of the 16-byte block size,
  # and don't evenly divide the plaintext either - matching how `Deflater`
  # calls `encrypt` with whatever, arbitrarily sized buffer zlib happens to
  # have flushed. This is the scenario that originally broke on JRuby: the
  # cipher must only ever be run over whole blocks internally, buffering any
  # trailing partial block until it's completed by the next chunk (or
  # flushed by `trailer`), regardless of how the caller chunks its writes.
  def test_encrypt_decrypt_round_trip_in_chunks
    plaintext = SecureRandom.random_bytes(100_003)

    encrypter = Zip::AESEncrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)
    encrypter.reset!
    header = encrypter.header('ignored')
    ciphertext = +''.b
    plaintext.each_char.each_slice(4097) { |chunk| ciphertext << encrypter.encrypt(chunk.join) }
    leftover, auth_code = split_trailer(encrypter.trailer)
    ciphertext << leftover

    decrypter = Zip::AESDecrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)
    decrypter.reset!(header)
    decrypted = +''.b
    ciphertext.each_char.each_slice(32_768) { |chunk| decrypted << decrypter.decrypt(chunk.join) }
    decrypter.check_integrity!(StringIO.new(auth_code))

    assert_equal plaintext, decrypted
  end

  def test_decrypt_with_wrong_password_raises
    encrypter = Zip::AESEncrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)
    encrypter.reset!
    header = encrypter.header('ignored')
    encrypter.encrypt('some data')

    decrypter = Zip::AESDecrypter.new('wrong_password', Zip::AESEncryption::STRENGTH_256_BIT)
    error = assert_raises(Zip::Error) { decrypter.reset!(header) }
    assert_equal 'Bad password', error.message
  end

  def test_tampered_ciphertext_fails_integrity_check
    encrypter = Zip::AESEncrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)
    encrypter.reset!
    header = encrypter.header('ignored')
    ciphertext = encrypter.encrypt('some secret data')
    leftover, auth_code = split_trailer(encrypter.trailer)
    ciphertext << leftover

    tampered = ciphertext.dup
    tampered[0] = (tampered.getbyte(0) ^ 0xFF).chr

    decrypter = Zip::AESDecrypter.new(@password, Zip::AESEncryption::STRENGTH_256_BIT)
    decrypter.reset!(header)
    decrypter.decrypt(tampered)
    error = assert_raises(Zip::Error) { decrypter.check_integrity!(StringIO.new(auth_code)) }
    assert_equal 'Integrity fault', error.message
  end
end
