# frozen_string_literal: true

require 'stringio'

require_relative 'fake_io'

module Zip
  module IOExtras # :nodoc:
    # Implements many of the convenience methods of IO
    # such as gets, getc, read, readline and readlines
    # depends on: input_finished?, produce_input and read
    module AbstractInputStream
      include Enumerable
      include FakeIO

      # How far past a limit `gets` may read to finish a multi-byte character.
      # `IO` allows itself the same slack; see `extra_limit` in `io.c`.
      MAX_CHAR_BYTES = 16 # :nodoc:

      # On MRI, finding the cut with a `StringIO` is faster than walking the
      # characters next to it for limits smaller than this. Other Rubies are
      # always walked as their `StringIO#gets` can't be relied on near invalid
      # bytes (JRuby) or to finish a multi-byte character (TruffleRuby).
      UTF8_WALK_MIN_LIMIT = 1000 # :nodoc:

      # Creates a new input stream wrapper.
      #
      # This method accepts the standard IO encoding options:
      # `external_encoding:`, `internal_encoding:` and `encoding:`.
      def initialize(**opts)
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
      def read(maxlen = nil, out_string = nil) # rubocop:disable Metrics/PerceivedComplexity,Metrics/CyclomaticComplexity
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
          tbuf.force_encoding(@internal_encoding || @external_encoding)
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
      # information. As with other Ruby streams, a limit is never allowed to
      # split a multi-byte character: the line is extended to the end of the
      # character that the limit falls inside.
      #
      # With arguments `sep` and `limit` given, combines the two behaviors.
      #
      # Optional keyword argument `chomp` specifies whether line separators
      # are to be omitted.
      def gets(sep = $INPUT_RECORD_SEPARATOR, limit = nil, chomp: false) # rubocop:disable Metrics/AbcSize,Metrics/CyclomaticComplexity,Metrics/PerceivedComplexity
        encoding = @internal_encoding || @external_encoding

        if sep.respond_to?(:to_int)
          limit = sep.to_int
          sep   = $INPUT_RECORD_SEPARATOR
        elsif sep&.empty?
          sep = "#{$INPUT_RECORD_SEPARATOR}#{$INPUT_RECORD_SEPARATOR}"
        end

        limit = nil if limit&.negative?

        return (+'').force_encoding(encoding) if limit&.zero?

        # The separator can straddle two chunks of input, so each search
        # restarts `sep.bytesize` bytes back.
        target       = limit && (limit + MAX_CHAR_BYTES)
        sep_index    = nil
        buffer_index = 0
        loop do
          sep_index = @output_buffer.index(sep, buffer_index) if sep
          break if sep_index || input_finished? || (target && @output_buffer.bytesize >= target)

          buffer_index = [buffer_index, @output_buffer.bytesize - sep.bytesize].max if sep
          @output_buffer << produce_input
        end

        return nil if @output_buffer.empty?

        cut_index = [limit, @output_buffer.bytesize].compact.min
        cut_index = [sep_index + sep.bytesize, cut_index].min if sep_index

        # A limit must not split a multi-byte character.
        if limit && encoding != Encoding::ASCII_8BIT
          cut_index = char_safe_cut_index(cut_index, encoding)
        end

        @lineno = @lineno.next
        @pos += cut_index
        data = @output_buffer.slice!(0, cut_index)
        data.chomp!(sep) if chomp && sep
        data.force_encoding(encoding)
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

      private

      # Finds the byte offset of the end of whichever character `cut_index`
      # falls inside, so a `gets` limit never splits a multi-byte character.
      #
      # UTF-8 (for large limits, or on any Ruby but MRI) is handled by walking
      # the characters next to the cut. Other multi-byte encodings can't be
      # framed from the middle of a string, so `rb_enc_right_char_head`, which
      # `StringIO` uses for this, is the best way to find their boundaries. It
      # isn't exposed to Ruby, so let a `StringIO` find the boundary for us.
      def char_safe_cut_index(cut_index, encoding)
        if encoding == Encoding::UTF_8 &&
           (cut_index > UTF8_WALK_MIN_LIMIT || RUBY_ENGINE != 'ruby')
          return utf8_char_safe_cut_index(cut_index)
        end

        # Keep the window a whole number of UTF-16/UTF-32 code units, as
        # TruffleRuby raises an `ArgumentError` for a UTF-16 string with an
        # odd byte length.
        window = @output_buffer.byteslice(0, (cut_index + MAX_CHAR_BYTES) & ~3)
        reader = StringIO.new(window.force_encoding(encoding))
        reader.gets(nil, cut_index)
        reader.pos
      end

      # `each_char` locates boundaries the same way `rb_enc_right_char_head`
      # does, treating invalid/truncated bytes as one-byte "characters" too
      # — unlike a Regexp match/scan, which raises `ArgumentError` on any
      # invalid byte anywhere in the window, even ones the match ignores.
      #
      # The walk only has to start at a known character boundary at or before
      # `cut_index`, which is cheap to find for UTF-8.
      def utf8_char_safe_cut_index(cut_index)
        start  = utf8_boundary_at_or_before(cut_index)
        window = @output_buffer.byteslice(start, cut_index - start + MAX_CHAR_BYTES)
        window.force_encoding(Encoding::UTF_8)

        start + window.each_char.reduce(0) do |pos, char|
          break pos if start + pos >= cut_index

          pos + char.bytesize
        end
      end

      # Finds a byte offset at or before `index` that is certain to be the
      # start of a character. UTF-8 continuation bytes (`10xxxxxx`) are only
      # ever consumed by a preceding lead byte, so any other byte (including
      # an invalid one) starts a character. A character has at most three
      # continuation bytes, so if none of the bytes in the last four offsets
      # is a lead byte then `index` is itself a boundary.
      def utf8_boundary_at_or_before(index)
        index.downto([index - 3, 0].max).find do |offset|
          # `index` can be the end of the buffer, which is also a boundary.
          (@output_buffer.getbyte(offset) || 0) & 0xC0 != 0x80
        end || index
      end
    end
  end
end
