# frozen_string_literal: true

module Zip
  # The superclass for all rubyzip error types. Simply rescue this one if
  # you don't need to know what sort of error has been raised.
  class Error < StandardError; end

  # Error raised if an unsupported compression method is used.
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

  # Error raised if there is a problem while decompressing an archive entry.
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

  # Error raised when trying to extract an archive entry over an
  # existing file.
  class DestinationExistsError < Error
    def initialize(destination)
      super()
      @destination = destination
    end

    def message
      "Cannot create file or directory '#{@destination}'. " \
      'A file already exists with that name.'
    end
  end

  # Error raised when trying to add an entry to an archive where the
  # entry name already exists.
  class EntryExistsError < Error
    def initialize(source, name)
      super()
      @source = source
      @name = name
    end

    def message
      "'#{@source}' failed. Entry #{@name} already exists."
    end
  end

  # Error raised when an entry name is invalid.
  class EntryNameError < Error
    def initialize(name = nil)
      super()
      @name = name
    end

    def message
      if @name.nil?
        'Illegal entry name. Names must have fewer than 65,536 characters.'
      else
        "Illegal entry name '#{@name}'. Names must not start with '/'."
      end
    end
  end

  # Error raised if an entry is larger on extraction than it is advertised
  # to be.
  class EntrySizeError < Error
    attr_reader :entry

    def initialize(entry)
      super()
      @entry = entry
    end

    def message
      "Entry '#{@entry.name}' should be #{@entry.size}B, but is larger when inflated."
    end
  end

  # Error raised if a split archive is read. Rubyzip does not support reading
  # split archives.
  class SplitArchiveError < Error
    def message
      'Rubyzip cannot extract from split archives at this time.'
    end
  end

  # Error raised if there is not enough metadata for the entry to be streamed.
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
