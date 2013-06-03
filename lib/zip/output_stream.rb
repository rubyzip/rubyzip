module Zip
  # ZipOutputStream is the basic class for writing zip files. It is
  # possible to create a ZipOutputStream object directly, passing
  # the zip file name to the constructor, but more often than not
  # the ZipOutputStream will be obtained from a ZipFile (perhaps using the
  # ZipFileSystem interface) object for a particular entry in the zip
  # archive.
  #
  # A ZipOutputStream inherits IOExtras::AbstractOutputStream in order
  # to provide an IO-like interface for writing to a single zip
  # entry. Beyond methods for mimicking an IO-object it contains
  # the method put_next_entry that closes the current entry
  # and creates a new.
  #
  # Please refer to ZipInputStream for example code.
  #
  # java.util.zip.ZipOutputStream is the original inspiration for this
  # class.

  class OutputStream
    include ::Zip::IOExtras::AbstractOutputStream

    attr_accessor :comment

    # Opens the indicated zip file. If a file with that name already
    # exists it will be overwritten.
    def initialize(fileName, stream=false)
      super()
      @fileName = fileName
      if stream
        @output_stream = ::StringIO.new
      else
        @output_stream = ::File.new(@fileName, "wb")
      end
      @entry_set = ::Zip::EntrySet.new
      @compressor = ::Zip::NullCompressor.instance
      @closed = false
      @currentEntry = nil
      @comment = nil
    end

    # Same as #initialize but if a block is passed the opened
    # stream is passed to the block and closed when the block
    # returns.
    class << self
      def open(fileName)
        return new(fileName) unless block_given?
        zos = new(fileName)
        yield zos
      ensure
        zos.close if zos
      end

	    # Same as #open but writes to a filestream instead
      def write_buffer
        zos = new('', true)
        yield zos
        return zos.close_buffer
      end
    end

    # Closes the stream and writes the central directory to the zip file
    def close
      return if @closed
      finalize_current_entry
      update_local_headers
      write_central_directory
      @output_stream.close
      @closed = true
    end

    # Closes the stream and writes the central directory to the zip file
    def close_buffer
      return @output_stream if @closed
      finalize_current_entry
      update_local_headers
      write_central_directory
      @closed = true
      @output_stream
    end

	  # Closes the current entry and opens a new for writing.
    # +entry+ can be a ZipEntry object or a string.
    def put_next_entry(entryname, comment = nil, extra = nil, compression_method = Entry::DEFLATED,  level = Zlib::DEFAULT_COMPRESSION)
      raise ZipError, "zip stream is closed" if @closed
      if entryname.kind_of?(Entry)
        new_entry = entryname
      else
        new_entry = Entry.new(@fileName, entryname.to_s)
      end
      new_entry.comment = comment if !comment.nil?
      if (!extra.nil?)
        new_entry.extra = ExtraField === extra ? extra : ExtraField.new(extra.to_s)
      end
      new_entry.compression_method = compression_method if !compression_method.nil?
      init_next_entry(new_entry, level)
      @currentEntry = new_entry
    end

    def copy_raw_entry(entry)
      entry = entry.dup
      raise ZipError, "zip stream is closed" if @closed
      raise ZipError, "entry is not a ZipEntry" if !entry.kind_of?(Entry)
      finalize_current_entry
      @entry_set << entry
      src_pos = entry.local_entry_offset
      entry.write_local_entry(@output_stream)
      @compressor = NullCompressor.instance
      entry.get_raw_input_stream do |is|
        is.seek(src_pos, IO::SEEK_SET)
        IOExtras.copy_stream_n(@output_stream, is, entry.compressed_size)
      end
      @compressor = NullCompressor.instance
      @currentEntry = nil
    end

    private

    def finalize_current_entry
      return unless @currentEntry
      finish
      @currentEntry.compressed_size = @output_stream.tell - @currentEntry.local_header_offset - @currentEntry.calculate_local_header_size
      @currentEntry.size = @compressor.size
      @currentEntry.crc = @compressor.crc
      @currentEntry = nil
      @compressor = NullCompressor.instance
    end

    def init_next_entry(entry, level = Zlib::DEFAULT_COMPRESSION)
      finalize_current_entry
      @entry_set << entry
      entry.write_local_entry(@output_stream)
      @compressor = get_compressor(entry, level)
    end

    def get_compressor(entry, level)
      case entry.compression_method
        when Entry::DEFLATED then Deflater.new(@output_stream, level)
        when Entry::STORED   then PassThruCompressor.new(@output_stream)
      else raise ZipCompressionMethodError,
        "Invalid compression method: '#{entry.compression_method}'"
      end
    end

    def update_local_headers
      pos = @output_stream.pos
      @entry_set.each do |entry|
        @output_stream.pos = entry.local_header_offset
        entry.write_local_entry(@output_stream)
      end
      @output_stream.pos = pos
    end

    def write_central_directory
      cdir = CentralDirectory.new(@entry_set, @comment)
      cdir.write_to_stream(@output_stream)
    end

    protected

    def finish
      @compressor.finish
    end

    public
    # Modeled after IO.<<
    def << (data)
      @compressor << data
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
