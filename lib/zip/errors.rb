# frozen_string_literal: true

module Zip
  class Error < StandardError; end
  class EntryExistsError < Error; end
  class DestinationFileExistsError < Error; end
  class CompressionMethodError < Error; end
  class EntryNameError < Error; end
  class EntrySizeError < Error; end
  class InternalError < Error; end
  class GPFBit3Error < Error; end
  class DecompressionError < Error; end
  class SplitArchiveError < Error; end
end
