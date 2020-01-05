module Zip
  class Inflater < Decompressor #:nodoc:all
    def initialize(*args)
      super

      @buffer = ''.dup
      @zlib_inflater = ::Zlib::Inflate.new(-Zlib::MAX_WBITS)
      @has_returned_empty_string = false
    end

    def sysread(length = nil, outbuf = '')
      while length.nil? || (@buffer.bytesize < length)
        break if input_finished?
        @buffer << produce_input
      end

      return value_when_finished if eof?

      outbuf.replace(@buffer.slice!(0...(length || @buffer.bytesize)))
    end

    def eof
      @buffer.empty? && input_finished?
    end

    alias_method :eof?, :eof

    private

    def produce_input
      retried = 0
      begin
        @zlib_inflater.inflate(input_stream.read(Decompressor::CHUNK_SIZE))
      rescue Zlib::BufError
        raise if retried >= 5 # how many times should we retry?
        retried += 1
        retry
      end
    rescue Zlib::Error => e
      raise(::Zip::DecompressionError, 'zlib error while inflating')
    end

    def input_finished?
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
