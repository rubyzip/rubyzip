module Zip
  class Decompressor #:nodoc:all
    CHUNK_SIZE = 32_768

    attr_reader :input_stream
    attr_reader :decompressed_size

    def initialize(input_stream, decompressed_size = nil)
      super()

      @input_stream = input_stream
      @decompressed_size = decompressed_size
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
