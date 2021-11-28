# frozen_string_literal: true

module Zip
  class Error < StandardError; end
  class EntryExistsError < Error; end
  class DestinationFileExistsError < Error; end
  class EntryNameError < Error; end
  class EntrySizeError < Error; end
  class InternalError < Error; end
  class DecompressionError < Error; end
  class SplitArchiveError < Error; end

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
