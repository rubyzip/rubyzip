# frozen_string_literal: true

require_relative 'test_helper'

class RequireTest < Minitest::Test
  # Guards the deferred `require 'openssl'` in Zip::AESEncryption#initialize.
  # These run in a subprocess because the test suite has already loaded
  # openssl by way of the AES tests.
  def subprocess(script)
    lib = File.expand_path('../lib', __dir__)
    IO.popen([RbConfig.ruby, '-I', lib, '-e', script], &:read)
  end

  def openssl_loaded
    "$LOADED_FEATURES.any? { |f| File.basename(f) == 'openssl.rb' }"
  end

  def test_requiring_zip_does_not_load_openssl
    assert_equal 'false', subprocess("require 'zip'; print #{openssl_loaded}")
  end

  def test_creating_an_aes_decrypter_loads_openssl
    script = "require 'zip'; " \
             "Zip::AESDecrypter.new('pwd', Zip::AESEncryption::STRENGTH_256_BIT); " \
             "print #{openssl_loaded}"

    assert_equal 'true', subprocess(script)
  end

  def test_aes_decryption_still_works_without_an_eager_require
    script = "require 'zip'; " \
             "d = Zip::AESDecrypter.new('password', Zip::AESEncryption::STRENGTH_128_BIT); " \
             "d.reset!([127, 254, 117, 113, 255, 209, 171, 131, 179, 106].pack('C*')); " \
             "print d.decrypt([34, 33, 106].map(&:chr).join) == [75, 4, 0].pack('C*')"

    assert_equal 'true', subprocess(script)
  end
end
