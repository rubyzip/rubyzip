module Zip
  class Error < StandardError; end
  class EntryExistsError < Error; end
  class DestinationFileExistsError < Error; end
  class CompressionMethodError < Error; end
  class EntryNameError < Error; end
  class InternalError < Error; end
end
