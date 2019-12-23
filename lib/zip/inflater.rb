module Zip
  class Inflater < Decompressor #:nodoc:all
    def initialize(input_stream, decrypter = NullDecrypter.new)
      super(input_stream)
      @zlib_inflater           = ::Zlib::Inflate.new(-Zlib::MAX_WBITS)
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
      return value_when_finished if @output_buffer.bytesize == 0 && eof?
      end_index = number_of_bytes.nil? ? @output_buffer.bytesize : number_of_bytes
      @output_buffer.slice!(0...end_index)
    end

    def produce_input
      sysread(::Zip::Decompressor::CHUNK_SIZE)
    end

    def eof
      @output_buffer.empty? && internal_input_finished?
    end

    alias_method :eof?, :eof

    private

    def internal_produce_input(buf = '')
      retried = 0
      begin
        @zlib_inflater.inflate(@decrypter.decrypt(@input_stream.read(Decompressor::CHUNK_SIZE, buf)))
      rescue Zlib::BufError
        raise if retried >= 5 # how many times should we retry?
        retried += 1
        retry
      end
    rescue Zlib::Error => e
      raise(::Zip::DecompressionError, 'zlib error while inflating')
    end

    def internal_input_finished?
      @zlib_inflater.finished?
    end

    def value_when_finished # mimic behaviour of ruby File object.
      return if @has_returned_empty_string
      @has_returned_empty_string = true
      ''
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
