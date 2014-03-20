module RubyZip
  module IOExtras #:nodoc:

    CHUNK_SIZE = 131072

    RANGE_ALL = 0..-1

    class << self
      def copy_stream(ostream, istream)
        ostream.write(istream.read(CHUNK_SIZE, '')) until istream.eof?
      end

      def copy_stream_n(ostream, istream, nbytes)
        toread = nbytes
        while toread > 0 && !istream.eof?
          tr = toread > CHUNK_SIZE ? CHUNK_SIZE : toread
          ostream.write(istream.read(tr, ''))
          toread -= tr
        end
      end
    end

    # Implements kind_of? in order to pretend to be an IO object
    module FakeIO
      def kind_of?(object)
        object == IO || super
      end
    end

  end # IOExtras namespace module
end

require 'rubyzip/ioextras/abstract_input_stream'
require 'rubyzip/ioextras/abstract_output_stream'

# Copyright (C) 2002-2004 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
