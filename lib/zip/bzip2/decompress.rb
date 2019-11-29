require 'bzip2/ffi'
require 'zip/bzip2/errors'

module Zip
  module Bzip2
    class Decompress
      OUT_BUFFER_SIZE = 4096

      class << self
        private

        def finalize(stream)
          -> (id) do
            res = ::Bzip2::FFI::Libbz2::BZ2_bzDecompressEnd(stream)
            check_error(res)
          end
        end
      end

      def initialize(options = {})
        small = options[:small]

        @stream = ::Bzip2::FFI::Libbz2::BzStream.new
        @out_eof = false

        res = ::Bzip2::FFI::Libbz2::BZ2_bzDecompressInit(stream, 0, small ? 1 : 0)
        check_error(res)

        ObjectSpace.define_finalizer(self, self.class.send(:finalize, stream))
      end

      def decompress(decompress_string)
        return nil if @out_eof

        out_buffer = nil
        in_buffer = nil
        begin
          out_buffer = ::FFI::MemoryPointer.new(1, OUT_BUFFER_SIZE)
          in_buffer = ::FFI::MemoryPointer.new(1, decompress_string.bytesize)

          in_buffer.write_bytes(decompress_string)
          stream[:next_in] = in_buffer
          stream[:avail_in] = in_buffer.size

          result = String.new
          while stream[:avail_in].positive?
            stream[:next_out] = out_buffer
            stream[:avail_out] = out_buffer.size

            res = ::Bzip2::FFI::Libbz2::BZ2_bzDecompress(stream)
            check_error(res)

            result += out_buffer.read_bytes(out_buffer.size - stream[:avail_out])

            if res == ::Bzip2::FFI::Libbz2::BZ_STREAM_END
              @out_eof = true

              res = ::Bzip2::FFI::Libbz2::BZ2_bzDecompressEnd(stream)
              ObjectSpace.undefine_finalizer(self)
              check_error(res)

              break
            end
          end
          result
        ensure
          in_buffer.free if in_buffer
          in_buffer = nil
          out_buffer.free if out_buffer
          out_buffer = nil
        end
      end

      def finished?
        @out_eof
      end

      protected

      attr_reader :stream

      private

      def check_error(res)
        return res if res >= 0

        error_class = case res
          when ::Bzip2::FFI::Libbz2::BZ_MEM_ERROR
            MemError
          when ::Bzip2::FFI::Libbz2::BZ_DATA_ERROR
            DataError
          when ::Bzip2::FFI::Libbz2::BZ_DATA_ERROR_MAGIC
            MagicDataError
          when ::Bzip2::FFI::Libbz2::BZ_CONFIG_ERROR
            ConfigError
          else
            raise UnexpectedError.new(res)
        end

        raise error_class.new
      end
    end
  end
end
