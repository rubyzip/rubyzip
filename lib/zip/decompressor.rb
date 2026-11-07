# frozen_string_literal: true

module Zip
  class Decompressor # :nodoc:all
    CHUNK_SIZE = 32_768

    REGISTER_LOCK = Mutex.new
    private_constant :REGISTER_LOCK

    # A frozen Hash, which #register replaces with a frozen copy, so that it
    # can be read by any Ractor.
    def self.decompressor_classes
      @decompressor_classes ||= {}.freeze
    end

    def self.register(compression_method, decompressor_class)
      REGISTER_LOCK.synchronize do
        @decompressor_classes =
          decompressor_classes.merge(compression_method => decompressor_class).freeze
      end
    end

    def self.find_by_compression_method(compression_method)
      decompressor_classes[compression_method]
    end

    attr_reader :decompressed_size, :input_stream

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
