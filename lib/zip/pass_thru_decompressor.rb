module Zip
  class PassThruDecompressor < Decompressor #:nodoc:all
    def initialize(*args)
      super
      @read_so_far = 0
      @has_returned_empty_string = false
    end

    def sysread(length = nil, outbuf = '')
      if eof?
        has_returned_empty_string_val = @has_returned_empty_string
        @has_returned_empty_string = true
        return '' unless has_returned_empty_string_val
        return
      end

      if length.nil? || (@read_so_far + length) > decompressed_size
        length = decompressed_size - @read_so_far
      end

      @read_so_far += length
      @input_stream.read(length, outbuf)
    end

    def eof
      @read_so_far >= decompressed_size
    end

    alias_method :eof?, :eof
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
