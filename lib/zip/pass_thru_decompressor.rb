module Zip
  class PassThruDecompressor < Decompressor #:nodoc:all
    def initialize(input_stream, chars_to_read)
      super(input_stream)
      @chars_to_read = chars_to_read
      @read_so_far = 0
      @has_returned_empty_string = false
    end

    def sysread(number_of_bytes = nil, buf = '')
      if eof?
        has_returned_empty_string_val = @has_returned_empty_string
        @has_returned_empty_string = true
        return '' unless has_returned_empty_string_val
        return
      end

      if number_of_bytes.nil? || @read_so_far + number_of_bytes > @chars_to_read
        number_of_bytes = @chars_to_read - @read_so_far
      end
      @read_so_far += number_of_bytes
      @input_stream.read(number_of_bytes, buf)
    end

    def eof
      @read_so_far >= @chars_to_read
    end

    alias_method :eof?, :eof
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
