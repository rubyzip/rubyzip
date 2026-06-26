# frozen_string_literal: true

module Zip
  class DecryptedIo # :nodoc:all
    CHUNK_SIZE = 32_768

    def initialize(io, decrypter, compressed_size)
      @io = io
      @decrypter = decrypter
      @bytes_remaining = compressed_size
      @buffer = +''.b
      # Ensures that integrity is only checked once,
      # even if read is called multiple times after the input has finished.
      @integrity_verified = false
    end

    def read(maxlen = nil)
      return (maxlen.nil? || maxlen.zero? ? '' : nil) if eof?

      while maxlen.nil? || (@buffer.bytesize < maxlen)
        break if input_finished?

        @buffer << produce_input
      end

      if input_finished? && !@integrity_verified
        @decrypter.check_integrity!(@io)
        @integrity_verified = true
      end

      @buffer.slice!(0...(maxlen || @buffer.bytesize))
    end

    private

    def eof?
      @buffer.empty? && input_finished?
    end

    def input_finished?
      !@bytes_remaining.positive?
    end

    def produce_input
      chunk_size = [@bytes_remaining, CHUNK_SIZE].min
      return '' unless chunk_size.positive?

      @bytes_remaining -= chunk_size
      @decrypter.decrypt(@io.read(chunk_size))
    end
  end
end
