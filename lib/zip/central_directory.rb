module Zip
  class CentralDirectory
    include Enumerable

    END_OF_CDS             = 0x06054b50
    ZIP64_END_OF_CDS       = 0x06064b50
    ZIP64_EOCD_LOCATOR     = 0x07064b50
    MAX_END_OF_CDS_SIZE    = 65536 + 18
    STATIC_EOCD_SIZE       = 22

    attr_reader :comment

    # Returns an Enumerable containing the entries.
    def entries
      @entry_set.entries
    end

    def initialize(entries = EntrySet.new, comment = '') #:nodoc:
      super()
      @entry_set = entries.kind_of?(EntrySet) ? entries : EntrySet.new(entries)
      @comment   = comment
    end

    def write_to_stream(io) #:nodoc:
      offset = io.tell
      @entry_set.each { |entry| entry.write_c_dir_entry(io) }
      write_e_o_c_d(io, offset)
    end

    def write_e_o_c_d(io, offset) #:nodoc:
      tmp = [
        END_OF_CDS,
        0, # @numberOfThisDisk
        0, # @numberOfDiskWithStartOfCDir
        @entry_set ? @entry_set.size : 0,
        @entry_set ? @entry_set.size : 0,
        cdir_size,
        offset,
        @comment ? @comment.length : 0
      ]
      io << tmp.pack('VvvvvVVv')
      io << @comment
    end

    private :write_e_o_c_d

    def cdir_size #:nodoc:
      # does not include eocd
      @entry_set.inject(0) do |value, entry|
        entry.cdir_header_size + value
      end
    end

    private :cdir_size

    def read_64_e_o_c_d(buf) #:nodoc:
      buf                                           = get_64_e_o_c_d(buf)
      @size_of_zip64_e_o_c_d                        = Entry.read_zip_64_long(buf)
      @version_made_by                              = Entry.read_zip_short(buf)
      @version_needed_for_extract                   = Entry.read_zip_short(buf)
      @number_of_this_disk                          = Entry.read_zip_long(buf)
      @number_of_disk_with_start_of_cdir            = Entry.read_zip_long(buf)
      @total_number_of_entries_in_cdir_on_this_disk = Entry.read_zip_64_long(buf)
      @size                                         = Entry.read_zip_64_long(buf)
      @size_in_bytes                                = Entry.read_zip_64_long(buf)
      @cdir_offset                                  = Entry.read_zip_64_long(buf)
      @zip_64_extensible                            = buf.slice!(0, buf.bytesize)
      raise ZipError, "Zip consistency problem while reading eocd structure" unless buf.size == 0
    end

    def read_e_o_c_d(buf) #:nodoc:
      buf                                           = get_e_o_c_d(buf)
      @number_of_this_disk                          = Entry.read_zip_short(buf)
      @number_of_disk_with_start_of_cdir            = Entry.read_zip_short(buf)
      @total_number_of_entries_in_cdir_on_this_disk = Entry.read_zip_short(buf)
      @size                                         = Entry.read_zip_short(buf)
      @size_in_bytes                                = Entry.read_zip_long(buf)
      @cdir_offset                                  = Entry.read_zip_long(buf)
      comment_length                                = Entry.read_zip_short(buf)
      @comment                                      = if comment_length <= 0
                                                        buf.slice!(0, buf.size)
                                                      else
                                                        buf.read(comment_length)
                                                      end
      raise ZipError, "Zip consistency problem while reading eocd structure" unless buf.size == 0
    end

    def read_central_directory_entries(io) #:nodoc:
      begin
        io.seek(@cdir_offset, IO::SEEK_SET)
      rescue Errno::EINVAL
        raise ZipError, "Zip consistency problem while reading central directory entry"
      end
      @entry_set = EntrySet.new
      @size.times do
        @entry_set << Entry.read_c_dir_entry(io)
      end
    end

    def read_from_stream(io) #:nodoc:
      buf = start_buf(io)
      if self.zip64_file?(buf)
        read_64_e_o_c_d(buf)
      else
        read_e_o_c_d(buf)
      end
      read_central_directory_entries(io)
    end

    def get_e_o_c_d(buf) #:nodoc:
      sig_index = buf.rindex([END_OF_CDS].pack('V'))
      raise ZipError, "Zip end of central directory signature not found" unless sig_index
      buf = buf.slice!((sig_index + 4)..(buf.bytesize))

      def buf.read(count)
        slice!(0, count)
      end

      buf
    end

    def zip64_file?(buf)
      buf.rindex([ZIP64_END_OF_CDS].pack('V')) && buf.rindex([ZIP64_EOCD_LOCATOR].pack('V'))
    end

    def start_buf(io)
      begin
        io.seek(-MAX_END_OF_CDS_SIZE, IO::SEEK_END)
      rescue Errno::EINVAL
        io.seek(0, IO::SEEK_SET)
      end
      io.read
    end

    def get_64_e_o_c_d(buf) #:nodoc:
      zip_64_start = buf.rindex([ZIP64_END_OF_CDS].pack('V'))
      raise ZipError, "Zip64 end of central directory signature not found" unless zip_64_start
      zip_64_locator = buf.rindex([ZIP64_EOCD_LOCATOR].pack('V'))
      raise ZipError, "Zip64 end of central directory signature locator not found" unless zip_64_locator
      buf = buf.slice!((zip_64_start + 4)..zip_64_locator)

      def buf.read(count)
        slice!(0, count)
      end

      buf
    end

    # For iterating over the entries.
    def each(&proc)
      @entry_set.each(&proc)
    end

    # Returns the number of entries in the central directory (and 
    # consequently in the zip archive).
    def size
      @entry_set.size
    end

    def self.read_from_stream(io) #:nodoc:
      cdir = new
      cdir.read_from_stream(io)
      return cdir
    rescue ZipError
      return nil
    end

    def ==(other) #:nodoc:
      return false unless other.kind_of?(CentralDirectory)
      @entry_set.entries.sort == other.entries.sort && comment == other.comment
    end
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
