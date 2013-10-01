require 'openssl'
require 'stringio'

module Zip
  class Decrypter < Decompressor #:nodoc:all
    VERIFIER_LENGTH = 2
    BLOCK_SIZE = 16
    AUTHENTICATION_CODE_LENGTH = 10

    attr_writer :password

    def initialize(input_stream, encryption_strength, entry_size, decompressor)
      super(input_stream)

      @data_length = entry_size - AUTHENTICATION_CODE_LENGTH
      @decompressor = decompressor
      @decompressor.input_stream = StringIO.new
      @encryption_strength = encryption_strength
      @prepared = false
    end

    def sysread(number_of_bytes = nil, buf = '')
      prepare_aes unless @prepared

      amount_to_read = @data_length
      raise RuntimeError, "Incorrect entry size given, can't proceed" if amount_to_read <= 0
      
      counter = 1
      while amount_to_read > 0
        set_iv(counter)

        encrypted = @input_stream.read([BLOCK_SIZE, amount_to_read].min)
        # Add the decrypted data to the IO object the decompressor interacts with
        @decompressor.input_stream.write(@cipher.update(encrypted))

        amount_to_read -= BLOCK_SIZE
        counter += 1
      end

      # TODO: Check Authentication value
      @input_stream.read(AUTHENTICATION_CODE_LENGTH)

      @decompressor.input_stream.rewind
      @decompressor.sysread
    end

    def input_finished?
      @decompressor.input_finished?
    end

    alias :eof :input_finished?
    alias :eof? :input_finished?

    private

    def prepare_aes
      raise RuntimeError, "No password given" if @password.nil?
      n = @encryption_strength + 1

      headers = {
        bits: 64 * n,
        key_length: 8 * n,
        mac_length: 8 * n,
        salt_length: 4 * n
      }

      raise RuntimeError, "AES-#{headers[:bits]} is not supported." unless [0x01, 0x02, 0x03].include? @encryption_strength

      @cipher = OpenSSL::Cipher::AES.new(headers[:bits], :CTR)
      @cipher.decrypt

      salt = @input_stream.read(headers[:salt_length])
      verification = @input_stream.read(VERIFIER_LENGTH)
      # The first few bytes are AES setup. Ensure we don't read beyond the end of the data during sysread
      @data_length -= (headers[:salt_length] + VERIFIER_LENGTH)

      key = OpenSSL::PKCS5.pbkdf2_hmac_sha1(
        @password,
        salt,
        1000,
        headers[:key_length] + headers[:mac_length] + VERIFIER_LENGTH
      )

      raise RuntimeError, "Incorrect password" unless key[-2..-1] == verification
      @cipher.key = key

      @prepared = true
    end

    def set_iv(counter)
      # Reverse engineered this value from Zip4j's AES support.
      @cipher.iv = [counter].pack("Vx12")
    end
  end
end