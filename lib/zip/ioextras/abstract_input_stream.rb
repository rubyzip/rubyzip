# frozen_string_literal: true

module Zip
  module IOExtras # :nodoc:
    # Implements many of the convenience methods of IO
    # such as gets, getc, read, readline and readlines
    # depends on: input_finished?, produce_input and read
    module AbstractInputStream
      include Enumerable
      include FakeIO

      def initialize # :nodoc:
        super
        @lineno        = 0
        @pos           = 0
        @output_buffer = +''.b
      end

      # Returns (or sets) the current line number in the decompressed
      # (possibly decrypted) data stream. See the Line Number documentation
      # for the IO class for more information.
      attr_accessor :lineno

      # Returns the current position (in bytes) in the decompressed (possibly
      # decrypted) data stream.
      attr_reader :pos

      # Reads bytes from the stream decompressed (possibly decrypted) data
      # stream. If `maxlen` is `nil`, reads all bytes; otherwise, reads up to
      # `maxlen` bytes. If `maxlen` is zero, returns an empty string.
      #
      # Returns a string (either a new string or the given `out_string`)
      # containing the bytes read. The string's encoding is the unchanged
      # encoding of `out_string`, if `out_string` is given; `ASCII-8BIT`,
      # otherwise.
      def read(maxlen = nil, out_string = nil) # rubocop:disable Metrics/PerceivedComplexity
        return (maxlen.nil? || maxlen.zero? ? '' : nil) if eof?

        tbuf = if @output_buffer.bytesize > 0
                 if maxlen && maxlen <= @output_buffer.bytesize
                   @output_buffer.slice!(0, maxlen)
                 else
                   maxlen -= @output_buffer.bytesize if maxlen
                   rbuf = produce_input(maxlen)
                   out  = @output_buffer
                   out << rbuf if rbuf
                   @output_buffer = +''.b
                   out
                 end
               else
                 produce_input(maxlen)
               end

        if tbuf.nil? || tbuf.empty?
          return nil if maxlen&.positive?

          return ''
        end

        @pos += tbuf.length

        if out_string.nil?
          tbuf.force_encoding(Encoding::ASCII_8BIT)
        else
          encoding = out_string.encoding
          out_string.replace(tbuf).force_encoding(encoding)
        end
      end

      # Reads and returns all remaining lines from the stream. See the Line IO
      # documentation in the IO class for more information.
      #
      # With no arguments given, returns lines as determined by line
      # separator `$/`, or `nil` if none.
      #
      # With only string argument `sep` given, returns lines as
      # determined by line separator `sep`, or `nil` if none. See the
      # Line Separator documentation in the IO class for more information.
      # The two special values for `sep` (`nil` and `""`) are honoured.
      #
      # With only integer argument `limit` given, limits the number of bytes
      # in each line; see the Line Limit documentation in the IO class for more
      # information.
      #
      # With arguments `sep` and `limit` given, combines the two behaviors.
      #
      # Optional keyword argument `chomp` specifies whether line separators
      # are to be omitted.
      def readlines(sep = $INPUT_RECORD_SEPARATOR, limit = nil, chomp: false)
        each(sep, limit, chomp: chomp).to_a
      end

      # Reads and returns a line from the stream. See the Line IO
      # documentation in the IO class for more information.
      #
      # With no arguments given, returns the next line as determined by line
      # separator `$/`, or `nil` if none.
      #
      # With only string argument `sep` given, returns the next line as
      # determined by line separator `sep`, or `nil` if none. See the
      # Line Separator documentation in the IO class for more information.
      # The two special values for `sep` (`nil` and `""`) are honoured.
      #
      # With only integer argument `limit` given, limits the number of bytes
      # in the line; see the Line Limit documentation in the IO class for more
      # information.
      #
      # With arguments `sep` and `limit` given, combines the two behaviors.
      #
      # Optional keyword argument `chomp` specifies whether line separators
      # are to be omitted.
      def gets(sep = $INPUT_RECORD_SEPARATOR, limit = nil, chomp: false)
        if sep.nil?
          return nil if eof?

          @lineno = @lineno.next
          return read(limit)
        end

        if sep.respond_to?(:to_int)
          limit = sep.to_int
          sep   = $INPUT_RECORD_SEPARATOR
        elsif sep&.empty?
          sep = "#{$INPUT_RECORD_SEPARATOR}#{$INPUT_RECORD_SEPARATOR}"
        end

        buffer_index = 0
        while (sep_index = @output_buffer.index(sep, buffer_index)).nil?
          break if limit && @output_buffer.bytesize >= limit

          if input_finished?
            return nil if @output_buffer.empty?

            @lineno = @lineno.next
            @pos += @output_buffer.bytesize
            return @output_buffer.slice!(0..)
          end

          buffer_index = [buffer_index, @output_buffer.bytesize - sep.bytesize].max
          @output_buffer << produce_input
        end

        limit ||= @output_buffer.bytesize
        cut_index = sep_index ? [sep_index + sep.bytesize, limit].min : limit
        @lineno = @lineno.next
        @pos += cut_index
        chomp ? @output_buffer.slice!(0, cut_index).chomp(sep) : @output_buffer.slice!(0, cut_index)
      end

      def ungetc(byte) # :nodoc:
        @output_buffer = byte.chr + @output_buffer
      end

      def flush # :nodoc:
        @output_buffer.slice!(0..)
      end

      # Reads a line as with #gets, but raises `EOFError` if already at
      # end-of-stream.
      #
      # Optional keyword argument `chomp` specifies whether line separators
      # are to be omitted.
      def readline(sep = $INPUT_RECORD_SEPARATOR, limit = nil, chomp: false)
        raise EOFError if eof?

        gets(sep, limit, chomp: chomp)
      end

      # Calls the block with each remaining line read from the stream.
      # Does nothing if already at end-of-stream. See the Line IO
      # documentation in the IO class for more information.
      #
      # With no arguments given, reads lines as determined by line separator
      # `$/`. With only string argument `sep` given, reads lines as determined
      # by line separator `sep`. See the Line Separator documentation in the
      # IO class for more information. The two special values for `sep`
      # (`nil` and `""`) are honoured.
      #
      # With only integer argument `limit` given, limits the number of bytes
      # in each line; see the Line Limit documentation in the IO class for
      # more information.
      #
      # With arguments `sep` and `limit` given, combines the two behaviors.
      #
      # Optional keyword argument `chomp` specifies whether line separators
      # are to be omitted.
      #
      # Returns an `Enumerator` if no block is given.
      def each(sep = $INPUT_RECORD_SEPARATOR, limit = nil, chomp: false)
        return to_enum(:each, sep, limit, chomp: chomp) unless block_given?

        while (line = gets(sep, limit, chomp: chomp))
          yield line
        end
      end

      alias each_line each

      # Returns `true` if the stream is positioned at its end, `false`
      # otherwise. See Position documentation in the IO class for more
      # information.
      def eof?
        @output_buffer.empty? && input_finished?
      end

      # Alias for compatibility. Remove for version 4.
      alias eof eof? # :nodoc:
    end
  end
end
