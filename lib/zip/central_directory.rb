# frozen_string_literal: true

module Zip
  class CentralDirectory
    include Enumerable

    END_OF_CDS             = 0x06054b50
    ZIP64_END_OF_CDS       = 0x06064b50
    ZIP64_EOCD_LOCATOR     = 0x07064b50
    MAX_END_OF_CDS_SIZE    = 65_536 + 18
    STATIC_EOCD_SIZE       = 22
    ZIP64_STATIC_EOCD_SIZE = 56

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
      cdir_offset = io.tell
      @entry_set.each { |entry| entry.write_c_dir_entry(io) }
      eocd_offset = io.tell
      cdir_size = eocd_offset - cdir_offset
      if ::Zip.write_zip64_support
        need_zip64_eocd = cdir_offset > 0xFFFFFFFF || cdir_size > 0xFFFFFFFF || @entry_set.size > 0xFFFF
        need_zip64_eocd ||= @entry_set.any? { |entry| entry.extra['Zip64'] }
        if need_zip64_eocd
          write_64_e_o_c_d(io, cdir_offset, cdir_size)
          write_64_eocd_locator(io, eocd_offset)
        end
      end
      write_e_o_c_d(io, cdir_offset, cdir_size)
    end

    def write_e_o_c_d(io, offset, cdir_size) #:nodoc:
      tmp = [
        END_OF_CDS,
        0, # @numberOfThisDisk
        0, # @numberOfDiskWithStartOfCDir
        @entry_set ? [@entry_set.size, 0xFFFF].min : 0,
        @entry_set ? [@entry_set.size, 0xFFFF].min : 0,
        [cdir_size, 0xFFFFFFFF].min,
        [offset, 0xFFFFFFFF].min,
        @comment ? @comment.bytesize : 0
      ]
      io << tmp.pack('VvvvvVVv')
      io << @comment
    end

    private :write_e_o_c_d

    def write_64_e_o_c_d(io, offset, cdir_size) #:nodoc:
      tmp = [
        ZIP64_END_OF_CDS,
        44, # size of zip64 end of central directory record (excludes signature and field itself)
        VERSION_MADE_BY,
        VERSION_NEEDED_TO_EXTRACT_ZIP64,
        0, # @numberOfThisDisk
        0, # @numberOfDiskWithStartOfCDir
        @entry_set ? @entry_set.size : 0, # number of entries on this disk
        @entry_set ? @entry_set.size : 0, # number of entries total
        cdir_size, # size of central directory
        offset # offset of start of central directory in its disk
      ]
      io << tmp.pack('VQ<vvVVQ<Q<Q<Q<')
    end

    private :write_64_e_o_c_d

    def write_64_eocd_locator(io, zip64_eocd_offset)
      tmp = [
        ZIP64_EOCD_LOCATOR,
        0, # number of disk containing the start of zip64 eocd record
        zip64_eocd_offset, # offset of the start of zip64 eocd record in its disk
        1 # total number of disks
      ]
      io << tmp.pack('VVQ<V')
    end

    private :write_64_eocd_locator

    def unpack_64_e_o_c_d(buffer) #:nodoc:
      index = buffer.rindex([ZIP64_END_OF_CDS].pack('V'))
      raise Error, 'Zip64 end of central directory signature not found' unless index

      l_index = buffer.rindex([ZIP64_EOCD_LOCATOR].pack('V'))
      raise Error, 'Zip64 end of central directory signature locator not found' unless l_index

      buf = buffer.slice(index..l_index)

      _, # ZIP64_END_OF_CDS signature. We know we have this at this point.
      @size_of_zip64_e_o_c_d,
      @version_made_by,
      @version_needed_for_extract,
      @number_of_this_disk,
      @number_of_disk_with_start_of_cdir,
      @total_number_of_entries_in_cdir_on_this_disk,
      @size,
      @size_in_bytes,
      @cdir_offset = buf.unpack('VQ<vvVVQ<Q<Q<Q<')

      zip64_extensible_data_size =
        @size_of_zip64_e_o_c_d - ZIP64_STATIC_EOCD_SIZE + 12
      @zip64_extensible_data = if zip64_extensible_data_size.zero?
                                 ''
                               else
                                 buffer.slice(
                                   ZIP64_STATIC_EOCD_SIZE,
                                   zip64_extensible_data_size
                                 )
                               end
    end

    def unpack_e_o_c_d(buffer) #:nodoc:
      index = buffer.rindex([END_OF_CDS].pack('V'))
      raise Error, 'Zip end of central directory signature not found' unless index

      buf = buffer.slice(index, buffer.size)

      _, # END_OF_CDS signature. We know we have this at this point.
      num_disk,
      num_disk_cdir,
      num_cdir_disk,
      num_entries,
      size_in_bytes,
      cdir_offset,
      comment_length = buf.unpack('VvvvvVVv')

      @number_of_this_disk = num_disk unless num_disk == 0xFFFF
      @number_of_disk_with_start_of_cdir = num_disk_cdir unless num_disk_cdir == 0xFFFF
      @total_number_of_entries_in_cdir_on_this_disk = num_cdir_disk unless num_cdir_disk == 0xFFFF
      @size = num_entries unless num_entries == 0xFFFF
      @size_in_bytes = size_in_bytes unless size_in_bytes == 0xFFFFFFFF
      @cdir_offset = cdir_offset unless cdir_offset == 0xFFFFFFFF

      @comment = if comment_length.positive?
                   buf.slice(STATIC_EOCD_SIZE, comment_length)
                 else
                   ''
                 end
    end

    def read_central_directory_entries(io) #:nodoc:
      # `StringIO` doesn't raise `EINVAL` if you seek beyond the current end,
      # so we need to catch that *and* query `io#eof?` here.
      eof = false
      begin
        io.seek(@cdir_offset, IO::SEEK_SET)
      rescue Errno::EINVAL
        eof = true
      end
      raise Error, 'Zip consistency problem while reading central directory entry' if eof || io.eof?

      @entry_set = EntrySet.new
      @size.times do
        entry = Entry.read_c_dir_entry(io)
        next unless entry

        offset = if entry.extra['Zip64']
                   entry.extra['Zip64'].relative_header_offset
                 else
                   entry.local_header_offset
                 end

        unless offset.nil?
          io_save = io.tell
          io.seek(offset, IO::SEEK_SET)
          entry.read_extra_field(read_local_extra_field(io))
          io.seek(io_save, IO::SEEK_SET)
        end

        @entry_set << entry
      end
    end

    def read_local_extra_field(io)
      buf = io.read(::Zip::LOCAL_ENTRY_STATIC_HEADER_LENGTH) || ''
      return '' unless buf.bytesize == ::Zip::LOCAL_ENTRY_STATIC_HEADER_LENGTH

      head, _, _, _, _, _, _, _, _, _, n_len, e_len = buf.unpack('VCCvvvvVVVvv')
      return '' unless head == ::Zip::LOCAL_ENTRY_SIGNATURE

      io.seek(n_len, IO::SEEK_CUR) # Skip over the entry name.
      io.read(e_len)
    end

    def read_from_stream(io) #:nodoc:
      buf = start_buf(io)
      unpack_64_e_o_c_d(buf) if zip64_file?(buf)
      unpack_e_o_c_d(buf)
      read_central_directory_entries(io)
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

    # For iterating over the entries.
    def each(&a_proc)
      @entry_set.each(&a_proc)
    end

    # Returns the number of entries in the central directory (and
    # consequently in the zip archive).
    def size
      @entry_set.size
    end

    def self.read_from_stream(io) #:nodoc:
      cdir = new
      cdir.read_from_stream(io)
      cdir
    rescue Error
      nil
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
