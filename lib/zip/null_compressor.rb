# frozen_string_literal: true

module Zip
  class NullCompressor < Compressor # :nodoc:all
    def self.instance
      INSTANCE
    end

    def <<(_data)
      raise IOError, 'closed stream'
    end

    attr_reader :size, :compressed_size

    # A frozen instance, without state, that any Ractor can use: Singleton
    # keeps a Mutex that a non-main Ractor cannot read.
    INSTANCE = new.freeze
    private_class_method :new, :allocate
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
