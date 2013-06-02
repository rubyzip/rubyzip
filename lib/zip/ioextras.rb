module Zip
  module IOExtras #:nodoc:

    CHUNK_SIZE = 131072

    RANGE_ALL = 0..-1

    def self.copy_stream(ostream, istream)
      s = ''
      ostream.write(istream.read(CHUNK_SIZE, s)) until istream.eof?
    end

    def self.copy_stream_n(ostream, istream, nbytes)
      s      = ''
      toread = nbytes
      while (toread > 0 && !istream.eof?)
        tr = toread > CHUNK_SIZE ? CHUNK_SIZE : toread
        ostream.write(istream.read(tr, s))
        toread -= tr
      end
    end


    # Implements kind_of? in order to pretend to be an IO object
    module FakeIO
      def kind_of?(object)
        object == IO || super
      end
    end

    # Implements many of the convenience methods of IO
    # such as gets, getc, readline and readlines
    # depends on: input_finished?, produce_input and read
    module AbstractInputStream
      include Enumerable
      include FakeIO

      def initialize
        super
        @lineno        = 0
        @pos           = 0
        @output_buffer = ""
      end

      attr_accessor :lineno
      attr_reader :pos

      def read(numberOfBytes = nil, buf = nil)
        tbuf = nil

        if @output_buffer.bytesize > 0
          if numberOfBytes <= @output_buffer.bytesize
            tbuf = @output_buffer.slice!(0, numberOfBytes)
          else
            numberOfBytes -= @output_buffer.bytesize if (numberOfBytes)
            rbuf = sysread(numberOfBytes, buf)
            tbuf = @output_buffer
            tbuf << rbuf if (rbuf)
            @output_buffer = ""
          end
        else
          tbuf = sysread(numberOfBytes, buf)
        end

        @pos += tbuf.length

        return nil unless (tbuf)

        if buf
          buf.replace(tbuf)
        else
          buf = tbuf
        end

        buf
      end

      def readlines(aSepString = $/)
        retVal = []
        each_line(aSepString) { |line| retVal << line }
        retVal
      end

      def gets(aSepString = $/, numberOfBytes = nil)
        @lineno = @lineno.next

        if numberOfBytes.respond_to?(:to_int)
          numberOfBytes = numberOfBytes.to_int
          aSepString = aSepString.to_str if aSepString
        elsif aSepString.respond_to?(:to_int)
          numberOfBytes = aSepString.to_int
          aSepString    = $/
        else
          numberOfBytes = nil
          aSepString = aSepString.to_str if aSepString
        end

        return read(numberOfBytes) if aSepString.nil?
        aSepString = "#{$/}#{$/}" if aSepString.empty?

        bufferIndex = 0
        overLimit   = (numberOfBytes && @output_buffer.bytesize >= numberOfBytes)
        while ((matchIndex = @output_buffer.index(aSepString, bufferIndex)) == nil && !overLimit)
          bufferIndex = [bufferIndex, @output_buffer.bytesize - aSepString.bytesize].max
          if input_finished?
            return @output_buffer.empty? ? nil : flush
          end
          @output_buffer << produce_input
          overLimit = (numberOfBytes && @output_buffer.bytesize >= numberOfBytes)
        end
        sepIndex = [matchIndex + aSepString.bytesize, numberOfBytes || @output_buffer.bytesize].min
        @pos     += sepIndex
        return @output_buffer.slice!(0...sepIndex)
      end

      def flush
        retVal        = @output_buffer
        @output_buffer=""
        return retVal
      end

      def readline(aSepString = $/)
        retVal = gets(aSepString)
        raise EOFError if retVal == nil
        retVal
      end

      def each_line(aSepString = $/)
        while true
          yield readline(aSepString)
        end
      rescue EOFError
      end

      alias_method :each, :each_line
    end


    # Implements many of the output convenience methods of IO.
    # relies on <<
    module AbstractOutputStream
      include FakeIO

      def write(data)
        self << data
        data.to_s.bytesize
      end


      def print(*params)
        self << params.join($,) << $\.to_s
      end

      def printf(aFormatString, *params)
        self << sprintf(aFormatString, *params)
      end

      def putc(anObject)
        self << case anObject
                when Fixnum then
                  anObject.chr
                when String then
                  anObject
                else
                  raise TypeError, "putc: Only Fixnum and String supported"
                end
        anObject
      end

      def puts(*params)
        params << "\n" if params.empty?
        params.flatten.each do |element|
          val = element.to_s
          self << val
          self << "\n" unless val[-1, 1] == "\n"
        end
      end

    end

  end # IOExtras namespace module
end

# Copyright (C) 2002-2004 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
