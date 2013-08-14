module Zip
  class ZipError < StandardError; end
  class ZipEntryExistsError < ZipError; end
  class ZipDestinationFileExistsError < ZipError; end
  class ZipCompressionMethodError < ZipError; end
  class ZipEntryNameError < ZipError; end
  class ZipInternalError < ZipError; end
end
