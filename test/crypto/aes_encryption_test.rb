# frozen_string_literal: true

require 'test_helper'

class AESDecrypterTest < MiniTest::Test
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
    @decrypter256.reset!([125, 138, 163, 42, 19, 1, 155, 66, 203, 174, 183, 235, 197, 122, 232, 68, 252, 225].pack('C*'))
    assert_equal 'a', @decrypter256.decrypt([161].map(&:chr).join)
  end

  def test_decrypt_aes128
    @decrypter128.reset!([127, 254, 117, 113, 255, 209, 171, 131, 179, 106].pack('C*'))
    assert_equal [75, 4, 0], @decrypter128.decrypt([34, 33, 106].map(&:chr).join).chars.map(&:ord)
  end

  def test_reset!
    @decrypter256.reset!([125, 138, 163, 42, 19, 1, 155, 66, 203, 174, 183, 235, 197, 122, 232, 68, 252, 225].pack('C*'))
    assert_equal 'a', @decrypter256.decrypt([161].map(&:chr).join)

    @decrypter256.reset!([118, 221, 166, 27, 165, 141, 24, 122, 227, 197, 52, 135, 222, 67, 221, 92, 231, 117].pack('C*'))
    assert_equal 'b', @decrypter256.decrypt([135].map(&:chr).join)
  end
end
