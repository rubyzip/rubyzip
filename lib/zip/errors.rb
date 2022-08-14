# frozen_string_literal: true

module Zip
  class Error < StandardError; end
  class EntryExistsError < Error; end
  class DestinationFileExistsError < Error; end
  class EntryNameError < Error; end
  class EntrySizeError < Error; end

  class CompressionMethodError < Error
    attr_reader :compression_method

    def initialize(method)
      super()
      @compression_method = method
    end

    def message
      "Unsupported compression method: #{COMPRESSION_METHODS[@compression_method]}."
    end
  end

  class DecompressionError < Error
    attr_reader :zlib_error

    def initialize(zlib_error)
      super()
      @zlib_error = zlib_error
    end

    def message
      "Zlib error ('#{@zlib_error.message}') while inflating."
    end
  end

  class SplitArchiveError < Error
    def message
      'Rubyzip cannot extract from split archives at this time.'
    end
  end

  class StreamingError < Error
    attr_reader :entry

    def initialize(entry)
      super()
      @entry = entry
    end

    def message
      "The local header of this entry ('#{@entry.name}') does not contain " \
      'the correct metadata for `Zip::InputStream` to be able to ' \
      'uncompress it. Please use `Zip::File` instead of `Zip::InputStream`.'
    end
  end
end
