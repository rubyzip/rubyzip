require 'zip/bzip2/decompress'

module Zip
  class Bzip2Decompressor < Decompressor #:nodoc:all
    def initialize(input_stream, decrypter = NullDecrypter.new)
      super(input_stream)
      @bzip2_ffi_decompressor  = Bzip2::Decompress.new
      @output_buffer           = ''.dup
      @has_returned_empty_string = false
      @decrypter = decrypter
    end

    def sysread(number_of_bytes = nil, buf = '')
      readEverything = number_of_bytes.nil?
      while readEverything || @output_buffer.bytesize < number_of_bytes
        break if internal_input_finished?
        @output_buffer << internal_produce_input(buf)
      end
      return value_when_finished if @output_buffer.bytesize == 0 && input_finished?
      end_index = number_of_bytes.nil? ? @output_buffer.bytesize : number_of_bytes
      @output_buffer.slice!(0...end_index)
    end

    def produce_input
      if @output_buffer.empty?
        internal_produce_input
      else
        @output_buffer.slice!(0...(@output_buffer.length))
      end
    end

    # to be used with produce_input, not read (as read may still have more data cached)
    # is data cached anywhere other than @outputBuffer?  the comment above may be wrong
    def input_finished?
      @output_buffer.empty? && internal_input_finished?
    end

    alias :eof input_finished?
    alias :eof? input_finished?

    private

    def internal_produce_input(buf = '')
      @bzip2_ffi_decompressor.decompress(@decrypter.decrypt(@input_stream.read(1024, buf)))
    rescue Bzip2::Error => e
      raise DecompressionError, e.message
    end

    def internal_input_finished?
      @bzip2_ffi_decompressor.finished?
    end

    def value_when_finished # mimic behaviour of ruby File object.
      return if @has_returned_empty_string
      @has_returned_empty_string = true
      ''
    end
  end
end