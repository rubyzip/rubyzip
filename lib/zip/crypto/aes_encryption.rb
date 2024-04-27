# frozen_string_literal: true

require 'openssl'

module Zip
  module AESEncryption # :nodoc:
    VERIFIER_LENGTH = 2
    BLOCK_SIZE = 16
    AUTHENTICATION_CODE_LENGTH = 10

    def initialize(password, strength)
      @password = password
      @strength = strength

      n = @strength + 1
      @headers = {
        bits: 64 * n,
        key_length: 8 * n,
        mac_length: 8 * n,
        salt_length: 4 * n
      }
      @counter = 0
    end

    def header_bytesize
      @headers[:salt_length] + VERIFIER_LENGTH
    end

    def gp_flags
      0x0001
    end
  end

  class AESDecrypter < Decrypter # :nodoc:
    include AESEncryption

    def decrypt(encrypted_data)
      amount_to_read = encrypted_data.size
      decrypted_data = +''

      while amount_to_read > 0
        @cipher.iv = [@counter + 1].pack('Vx12')
        begin_index = BLOCK_SIZE * @counter
        end_index = BLOCK_SIZE * @counter + [BLOCK_SIZE, amount_to_read].min - 1
        decrypted_data << @cipher.update(encrypted_data[begin_index..end_index])
        amount_to_read -= BLOCK_SIZE
        @counter += 1
      end

      decrypted_data
    end

    def reset!(header)
      raise RuntimeError, "Unsupported encryption AES-#{@headers[:bits]}" unless [0x01, 0x02, 0x03].include? @strength

      @cipher = OpenSSL::Cipher::AES.new(@headers[:bits], :CTR)
      @cipher.decrypt
      salt = header[0..@headers[:salt_length] - 1]
      pwv = header[-VERIFIER_LENGTH..-1]
      key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(@password, salt, 1000, @headers[:key_length] + @headers[:mac_length] + VERIFIER_LENGTH)

      raise RuntimeError, 'Incorrect password' if key[-VERIFIER_LENGTH..-1] != pwv

      @cipher.key = key[0..@headers[:key_length] - 1]
    end
  end
end
