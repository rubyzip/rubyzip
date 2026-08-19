# frozen_string_literal: true

module Zip
  module IOExtras # :nodoc:
    CHUNK_SIZE = 131_072

    class << self
      def copy_stream(ostream, istream)
        ostream.write(istream.read(CHUNK_SIZE, +'')) until istream.eof?
      end

      def copy_stream_n(ostream, istream, nbytes)
        toread = nbytes
        while toread > 0 && !istream.eof?
          tr = [toread, CHUNK_SIZE].min
          chunk = istream.read(tr, +'')
          break if !chunk || chunk.empty?

          ostream.write(chunk)
          toread -= chunk.bytesize
        end
      end
    end
  end
end

require_relative 'ioextras/abstract_input_stream'
require_relative 'ioextras/abstract_output_stream'

# Copyright (C) 2002-2004 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
