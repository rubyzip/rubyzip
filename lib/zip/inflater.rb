module Zip
  class Inflater < Decompressor #:nodoc:all
    def initialize(input_stream)
      super
      @zlib_inflater           = ::Zlib::Inflate.new(-Zlib::MAX_WBITS)
      @output_buffer           = ''
      @output_buffer_pos       = 0
      @has_returned_empty_string = false
    end

    def sysread(number_of_bytes = nil, buf = '')
      buf ||= ''
      buf.clear
      readEverything = number_of_bytes.nil?
      if readEverything
        buf << @output_buffer[@output_buffer_pos...@output_buffer.bytesize]

        move_output_buffer_pos(buf.bytesize)
      else
        buf << @output_buffer[@output_buffer_pos, number_of_bytes]

        move_output_buffer_pos(buf.bytesize)

        if buf.bytesize == number_of_bytes
          return buf
        end
      end
      while readEverything || buf.bytesize + @output_buffer.bytesize < number_of_bytes
        break if internal_input_finished?
        @output_buffer << internal_produce_input
      end
      return value_when_finished(number_of_bytes, buf) if @output_buffer.bytesize == 0 && input_finished?
      end_index = (number_of_bytes.nil? ? @output_buffer.bytesize : number_of_bytes) - buf.bytesize
      data = @output_buffer[0...end_index]

      move_output_buffer_pos(data.bytesize)

      buf << data
    end

    def produce_input
      sysread()
    end

    # to be used with produce_input, not read (as read may still have more data cached)
    # is data cached anywhere other than @outputBuffer?  the comment above may be wrong
    def input_finished?
      @output_buffer.empty? && internal_input_finished?
    end

    alias :eof :input_finished?
    alias :eof? :input_finished?

    private

    def move_output_buffer_pos(inc)
      @output_buffer_pos += inc
      if @output_buffer_pos == @output_buffer.bytesize
        @output_buffer.clear
        @output_buffer_pos = 0
      end
    end

    def internal_produce_input
      buf = ''
      retried = 0
      begin
        @zlib_inflater.inflate(@input_stream.read(Decompressor::CHUNK_SIZE, buf))
      rescue Zlib::BufError
        raise if retried >= 5 # how many times should we retry?
        retried += 1
        retry
      end
    end

    def internal_input_finished?
      @zlib_inflater.finished?
    end

    def value_when_finished(number_of_bytes, buf) # mimic behaviour of ruby File object.
      if number_of_bytes.nil?
        buf
      elsif buf.bytesize == 0
        nil
      else
        buf
      end
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
