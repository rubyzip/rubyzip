# frozen_string_literal: true

require 'securerandom'

module Zip
  module AESEncryption # :nodoc:
    VERIFIER_LENGTH = 2
    BLOCK_SIZE = 16
    AUTHENTICATION_CODE_LENGTH = 10

    VERSION_AE_1 = 0x01
    VERSION_AE_2 = 0x02

    VERSIONS = [
      VERSION_AE_1,
      VERSION_AE_2
    ].freeze

    STRENGTH_128_BIT = 0x01
    STRENGTH_192_BIT = 0x02
    STRENGTH_256_BIT = 0x03

    STRENGTHS = [
      STRENGTH_128_BIT,
      STRENGTH_192_BIT,
      STRENGTH_256_BIT
    ].freeze

    BITS = {
      STRENGTH_128_BIT => 128,
      STRENGTH_192_BIT => 192,
      STRENGTH_256_BIT => 256
    }.freeze

    KEY_LENGTHS = {
      STRENGTH_128_BIT => 16,
      STRENGTH_192_BIT => 24,
      STRENGTH_256_BIT => 32
    }.freeze

    SALT_LENGTHS = {
      STRENGTH_128_BIT => 8,
      STRENGTH_192_BIT => 12,
      STRENGTH_256_BIT => 16
    }.freeze

    def initialize(password, strength)
      # Loaded here rather than at the top of the file so that `require 'zip'`
      # does not pull in openssl. Only AES-encrypted archives need it, and it
      # is the single largest cost of loading this library.
      require 'openssl'

      @password = password
      @strength = strength
      @bits = BITS[@strength]
      @key_length = KEY_LENGTHS[@strength]
      @salt_length = SALT_LENGTHS[@strength]
    end

    def header_bytesize
      @salt_length + VERIFIER_LENGTH
    end

    def gp_flags
      0x0001
    end

    private

    # Derive the encryption key, HMAC key and password-verification value
    # from the password and a salt, as specified by the WinZip AES format.
    def derive_keys(salt)
      raise Error, "Unsupported encryption AES-#{@bits}" unless STRENGTHS.include? @strength

      key_material = OpenSSL::KDF.pbkdf2_hmac(
        @password,
        salt:       salt,
        iterations: 1000,
        length:     (2 * @key_length) + VERIFIER_LENGTH,
        hash:       'sha1'
      )

      [
        key_material[0...@key_length],
        key_material[@key_length...(2 * @key_length)],
        key_material[-VERIFIER_LENGTH..]
      ]
    end
  end

  class AESEncrypter < Encrypter # :nodoc:
    include AESEncryption

    def header(_mtime)
      @salt + @pwd_verify
    end

    # `Deflater`/`PassThruCompressor` call this with whatever, arbitrarily
    # sized (and not necessarily block-aligned) buffer they happen to have
    # flushed, potentially many times per entry. Only whole 16-byte blocks
    # are actually run through the cipher here; any trailing partial block
    # is buffered in `@pending` until either more data completes it or
    # `trailer` forces the final flush. This keeps the CTR counter aligned
    # with the true byte offset in the plaintext stream regardless of how
    # callers happen to chunk their writes.
    def encrypt(data)
      @pending << data
      encrypted_data = encrypt_blocks
      @hmac.update(encrypted_data)
      encrypted_data
    end

    def data_descriptor(*)
      ''
    end

    def trailer
      encrypted_data = encrypt_blocks(final: true)
      @hmac.update(encrypted_data)
      encrypted_data + @hmac.digest[0...AUTHENTICATION_CODE_LENGTH]
    end

    def crc(_computed_crc)
      0
    end

    def reset!
      @salt = SecureRandom.random_bytes(@salt_length)
      enc_key, enc_hmac_key, @pwd_verify = derive_keys(@salt)

      @counter = 0
      @pending = +''.b
      @cipher = OpenSSL::Cipher::AES.new(@bits, :CTR)
      @cipher.encrypt
      @cipher.key = enc_key
      @hmac = OpenSSL::HMAC.new(enc_hmac_key, OpenSSL::Digest.new('SHA1'))
    end

    def prepare_entry(entry)
      entry.prep_aes_extra(AESEncryption::VERSION_AE_2, @strength)
    end

    private

    def encrypt_blocks(final: false)
      length = final ? @pending.bytesize : (@pending.bytesize / BLOCK_SIZE) * BLOCK_SIZE
      return '' if length.zero?

      data = @pending.slice!(0, length)
      encrypted_data = +''.b
      offset = 0

      while offset < data.bytesize
        @cipher.iv = [@counter + 1].pack('Vx12')
        encrypted_data << @cipher.update(data[offset, BLOCK_SIZE])
        @counter += 1
        offset += BLOCK_SIZE
      end

      # JRuby requires finalization of the cipher when the last block fed to
      # it is a partial one. This is a bug, as noted in
      # jruby/jruby-openssl#182 and jruby/jruby-openssl#183.
      encrypted_data << @cipher.final if final && defined?(JRUBY_VERSION)
      encrypted_data
    end
  end

  class AESDecrypter < Decrypter # :nodoc:
    include AESEncryption

    def decrypt(encrypted_data)
      @hmac.update(encrypted_data)

      idx = 0
      decrypted_data = +''
      amount_to_read = encrypted_data.size

      while amount_to_read.positive?
        @cipher.iv = [@counter + 1].pack('Vx12')
        begin_index = BLOCK_SIZE * idx
        end_index = begin_index + [BLOCK_SIZE, amount_to_read].min
        decrypted_data << @cipher.update(encrypted_data[begin_index...end_index])
        amount_to_read -= BLOCK_SIZE
        @counter += 1
        idx += 1
      end

      # JRuby requires finalization of the cipher. This is a bug, as noted in
      # jruby/jruby-openssl#182 and jruby/jruby-openssl#183.
      decrypted_data << @cipher.final if defined?(JRUBY_VERSION)
      decrypted_data
    end

    def reset!(header)
      salt = header[0...@salt_length]
      pwd_verify = header[-VERIFIER_LENGTH..]
      enc_key, enc_hmac_key, enc_pwd_verify = derive_keys(salt)

      raise Error, 'Bad password' if enc_pwd_verify != pwd_verify

      @counter = 0
      @cipher = OpenSSL::Cipher::AES.new(@bits, :CTR)
      @cipher.decrypt
      @cipher.key = enc_key
      @hmac = OpenSSL::HMAC.new(enc_hmac_key, OpenSSL::Digest.new('SHA1'))
    end

    def check_integrity!(io)
      auth_code = io.read(AUTHENTICATION_CODE_LENGTH)
      raise Error, 'Integrity fault' if @hmac.digest[0...AUTHENTICATION_CODE_LENGTH] != auth_code
    end
  end
end
