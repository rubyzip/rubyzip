# frozen_string_literal: true

##
module Zip
  # InputStream is the basic class for reading zip entries in a
  # zip file. It is possible to create a InputStream object directly,
  # passing the zip file name to the constructor, but more often than not
  # the InputStream will be obtained from a File (perhaps using the
  # ZipFileSystem interface) object for a particular entry in the zip
  # archive.
  #
  # A InputStream inherits IOExtras::AbstractInputStream in order
  # to provide an IO-like interface for reading from a single zip
  # entry. Beyond methods for mimicking an IO-object it contains
  # the method get_next_entry for iterating through the entries of
  # an archive. get_next_entry returns a Entry object that describes
  # the zip entry the InputStream is currently reading from.
  #
  # Example that creates a zip archive with ZipOutputStream and reads it
  # back again with a InputStream.
  #
  #   require 'zip'
  #
  #   Zip::OutputStream.open("my.zip") do |io|
  #
  #     io.put_next_entry("first_entry.txt")
  #     io.write "Hello world!"
  #
  #     io.put_next_entry("adir/first_entry.txt")
  #     io.write "Hello again!"
  #   end
  #
  #
  #   Zip::InputStream.open("my.zip") do |io|
  #
  #     while (entry = io.get_next_entry)
  #       puts "Contents of #{entry.name}: '#{io.read}'"
  #     end
  #   end
  #
  # java.util.zip.ZipInputStream is the original inspiration for this
  # class.
  class InputStream
    CHUNK_SIZE = 32_768 # :nodoc:

    include ::Zip::IOExtras::AbstractInputStream

    # Opens the indicated zip file. An exception is thrown
    # if the specified offset in the specified filename is
    # not a local zip entry header.
    #
    # @param context [String||IO||StringIO] file path or IO/StringIO object
    # @param offset [Integer] offset in the IO/StringIO
    def initialize(context, offset: 0, decrypter: nil)
      super()
      @archive_io = get_io(context, offset)
      @decompressor = ::Zip::NullDecompressor
      @decrypter = decrypter || ::Zip::NullDecrypter.new
      @current_entry = nil
      @complete_entry = nil
    end

    # Close this InputStream. All further IO will raise an IOError.
    def close
      @archive_io.close
    end

    # Returns an Entry object and positions the stream at the beginning of
    # the entry data. It is necessary to call this method on a newly created
    # InputStream before reading from the first entry in the archive.
    # Returns nil when there are no more entries.
    def get_next_entry
      unless @current_entry.nil?
        raise StreamingError, @current_entry if @current_entry.incomplete?

        @archive_io.seek(@current_entry.next_header_offset, IO::SEEK_SET)
      end

      open_entry
    end

    # Rewinds the stream to the beginning of the current entry.
    def rewind
      return if @current_entry.nil?

      @lineno = 0
      @pos    = 0
      @archive_io.seek(@current_entry.local_header_offset, IO::SEEK_SET)
      open_entry
    end

    # Modeled after IO.sysread
    def sysread(length = nil, outbuf = +'')
      @decompressor.read(length, outbuf)
    end

    # Returns the size of the current entry, or `nil` if there isn't one.
    def size
      return if @current_entry.nil?

      @current_entry.size
    end

    class << self
      # Same as #initialize but if a block is passed the opened
      # stream is passed to the block and closed when the block
      # returns.
      def open(filename_or_io, offset: 0, decrypter: nil)
        zio = new(filename_or_io, offset: offset, decrypter: decrypter)
        return zio unless block_given?

        begin
          yield zio
        ensure
          zio.close if zio
        end
      end
    end

    protected

    def get_io(io_or_file, offset = 0) # :nodoc:
      if io_or_file.respond_to?(:seek)
        io = io_or_file.dup
        io.seek(offset, ::IO::SEEK_SET)
        io
      else
        file = ::File.open(io_or_file, 'rb')
        file.seek(offset, ::IO::SEEK_SET)
        file
      end
    end

    def open_entry # :nodoc:
      @current_entry = ::Zip::Entry.read_local_entry(@archive_io)
      return if @current_entry.nil?

      if @current_entry.encrypted? && @decrypter.kind_of?(NullDecrypter)
        raise Error,
              'A password is required to decode this zip file'
      end

      if @current_entry.incomplete? && @current_entry.compressed_size == 0 && !@complete_entry
        raise StreamingError, @current_entry
      end

      @decrypted_io = get_decrypted_io
      @decompressor = get_decompressor
      flush
      @current_entry
    end

    def get_decrypted_io # :nodoc:
      header = @archive_io.read(@decrypter.header_bytesize)
      @decrypter.reset!(header)

      compressed_size =
        if @current_entry.incomplete? && @current_entry.crc == 0 &&
           @current_entry.compressed_size == 0 && @complete_entry
          @complete_entry.compressed_size
        else
          @current_entry.compressed_size
        end

      if @decrypter.kind_of?(::Zip::AESDecrypter)
        compressed_size -= @decrypter.header_bytesize
        compressed_size -= ::Zip::AESEncryption::AUTHENTICATION_CODE_LENGTH
      end

      ::Zip::DecryptedIo.new(@archive_io, @decrypter, compressed_size)
    end

    def get_decompressor # :nodoc:
      return ::Zip::NullDecompressor if @current_entry.nil?

      decompressed_size =
        if @current_entry.incomplete? && @current_entry.crc == 0 &&
           @current_entry.size == 0 && @complete_entry
          @complete_entry.size
        else
          @current_entry.size
        end

      decompressor_class = ::Zip::Decompressor.find_by_compression_method(
        @current_entry.compression_method
      )
      if decompressor_class.nil?
        raise ::Zip::CompressionMethodError, @current_entry.compression_method
      end

      decompressor_class.new(@decrypted_io, decompressed_size)
    end

    def produce_input # :nodoc:
      @decompressor.read(CHUNK_SIZE)
    end

    def input_finished? # :nodoc:
      @decompressor.eof
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
