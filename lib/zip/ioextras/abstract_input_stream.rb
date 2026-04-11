# frozen_string_literal: true

module Zip
  module IOExtras # :nodoc:
    # Implements many of the convenience methods of IO
    # such as gets, getc, read, readline and readlines
    # depends on: input_finished?, produce_input and read
    module AbstractInputStream # :nodoc:
      include Enumerable
      include FakeIO

      def initialize
        super
        @lineno        = 0
        @pos           = 0
        @output_buffer = +''.b
      end

      attr_accessor :lineno
      attr_reader :pos

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

      def readlines(sep = $INPUT_RECORD_SEPARATOR, limit = nil, chomp: false)
        each(sep, limit, chomp: chomp).to_a
      end

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

      def ungetc(byte)
        @output_buffer = byte.chr + @output_buffer
      end

      def flush
        @output_buffer.slice!(0..)
      end

      def readline(sep = $INPUT_RECORD_SEPARATOR, limit = nil, chomp: false)
        raise EOFError if eof?

        gets(sep, limit, chomp: chomp)
      end

      def each(sep = $INPUT_RECORD_SEPARATOR, limit = nil, chomp: false)
        return to_enum(:each, sep, limit, chomp: chomp) unless block_given?

        while (line = gets(sep, limit, chomp: chomp))
          yield line
        end
      end

      alias each_line each

      def eof?
        @output_buffer.empty? && input_finished?
      end

      # Alias for compatibility. Remove for version 4.
      alias eof eof?
    end
  end
end
