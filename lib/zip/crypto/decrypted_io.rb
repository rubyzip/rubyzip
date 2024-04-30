# frozen_string_literal: true

module Zip
  class DecryptedIo # :nodoc:all
    CHUNK_SIZE = 32_768

    def initialize(io, decrypter, compressed_size)
      @io = io
      @decrypter = decrypter
      @offset = io.tell
      @compressed_size = compressed_size
    end

    def read(length = nil, outbuf = +'')
      return (length.nil? || length.zero? ? '' : nil) if eof

      while length.nil? || (buffer.bytesize < length)
        break if input_finished?

        buffer << produce_input
      end

      check_aes_integrity
      outbuf.replace(buffer.slice!(0...(length || output_buffer.bytesize)))
    end

    private

    def eof
      buffer.empty? && input_finished?
    end

    def buffer
      @buffer ||= +''
    end

    def pos
      @io.tell - @offset
    end

    def input_finished?
      @io.eof || pos >= @compressed_size
    end

    def produce_input
      chunk_size = [CHUNK_SIZE, @compressed_size - pos].min
      @decrypter.decrypt(@io.read(chunk_size))
    end

    def check_aes_integrity
      return unless @decrypter.kind_of?(::Zip::AESDecrypter)
      return unless input_finished?

      @decrypter.check_integrity(@io.read(::Zip::AESEncryption::AUTHENTICATION_CODE_LENGTH))
    end
  end
end
