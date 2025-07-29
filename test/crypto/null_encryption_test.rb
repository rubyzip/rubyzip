# frozen_string_literal: true

require_relative '../test_helper'

class NullEncrypterTest < Minitest::Test
  def setup
    @encrypter = ::Zip::NullEncrypter.new
  end

  def test_header_bytesize
    assert_equal 0, @encrypter.header_bytesize
  end

  def test_gp_flags
    assert_equal 0, @encrypter.gp_flags
  end

  def test_header
    assert_empty @encrypter.header(nil)
  end

  def test_encrypt
    assert_nil @encrypter.encrypt(nil)

    ['', 'a' * 10, 0xffffffff].each do |data|
      assert_equal data, @encrypter.encrypt(data)
    end
  end

  def test_reset!
    assert_respond_to @encrypter, :reset!
  end
end
