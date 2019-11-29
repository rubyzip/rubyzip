module Zip
  module Bzip2
    # Base class for Zip::Bzip2 exceptions.
    class Error < IOError
    end

    # Raised if a failure occurred allocating memory to complete a request.
    class MemError < Error
      # Initializes a new instance of MemError.
      #
      # @private
      def initialize #:nodoc:
        super('Could not allocate enough memory to perform this request')
      end
    end

    # Raised if a data integrity error is detected (a mismatch between
    # stored and computed CRCs or another anomaly in the compressed data).
    class DataError < Error
      # Initializes a new instance of DataError.
      #
      # @param message [String] Exception message (overrides the default).
      # @private
      def initialize(message = nil) #:nodoc:
        super(message || 'Data integrity error detected (mismatch between stored and computed CRCs, or other anomaly in the compressed data)')
      end
    end

    # Raised if the compressed data does not start with the correct magic
    # bytes ('BZh').
    class MagicDataError < DataError
      # Initializes a new instance of MagicDataError.
      #
      # @private
      def initialize #:nodoc:
        super('Compressed data does not start with the correct magic bytes (\'BZh\')')
      end
    end

    # Raised if libbz2 detects that it has been improperly compiled.
    class ConfigError < DataError
      # Initializes a new instance of ConfigError.
      #
      # @private
      def initialize #:nodoc:
        super('libbz2 has been improperly compiled on your platform')
      end
    end

    # Raised if libbz2 reported an unexpected error code.
    class UnexpectedError < Error
      # Initializes a new instance of UnexpectedError.
      #
      # @param error_code [Integer] The error_code reported by libbz2.
      # @private
      def initialize(error_code) #:nodoc:
        super("An unexpected error was detected (error code: #{error_code})")
      end
    end
  end
end
