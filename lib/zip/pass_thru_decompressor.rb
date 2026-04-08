# frozen_string_literal: true

module Zip
  class PassThruDecompressor < Decompressor # :nodoc:all
    def initialize(*args)
      super
      @read_so_far = 0
    end

    def read(maxlen = nil)
      return (maxlen.nil? || maxlen.zero? ? '' : nil) if eof?

      if maxlen.nil? || (@read_so_far + maxlen) > decompressed_size
        maxlen = decompressed_size - @read_so_far
      end

      @read_so_far += maxlen
      input_stream.read(maxlen)
    end

    def eof?
      @read_so_far >= decompressed_size
    end

    # Alias for compatibility. Remove for version 4.
    alias eof eof?
  end

  ::Zip::Decompressor.register(::Zip::COMPRESSION_METHOD_STORE, ::Zip::PassThruDecompressor)
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
