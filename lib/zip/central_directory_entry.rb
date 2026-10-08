# frozen_string_literal: true

module Zip
  # An entry as the central directory describes it.
  module CentralDirectoryEntry # :nodoc:all
    attr_accessor :local_extra_field_deferred

    def unpack_c_dir_entry(buf) # :nodoc:
      @header_signature,
        @version, # version of encoding software
        @fstype, # filesystem type
        @version_needed_to_extract,
        @gp_flags,
        @compression_method,
        @last_mod_time,
        @last_mod_date,
        @crc,
        @compressed_size,
        @size,
        @name_length,
        @extra_length,
        @comment_length,
        _, # diskNumberStart
        @internal_file_attributes,
        @external_file_attributes,
        @local_header_offset = buf.unpack('VCCvvvvvVVVvvvvvVV')
    end

    def set_ftype_from_c_dir_entry # :nodoc:
      @ftype = case @fstype
               when ::Zip::FSTYPE_UNIX
                 @unix_perms = (@external_file_attributes >> 16) & 0o7777
                 case (@external_file_attributes >> 28)
                 when ::Zip::FILE_TYPE_DIR
                   :directory
                 when ::Zip::FILE_TYPE_FILE
                   :file
                 when ::Zip::FILE_TYPE_SYMLINK
                   :symlink
                 else
                   # Best case guess for whether it is a file or not.
                   # Otherwise this would be set to unknown and that
                   # entry would never be able to be extracted.
                   if name_is_directory?
                     :directory
                   else
                     :file
                   end
                 end
               else
                 if name_is_directory?
                   :directory
                 else
                   :file
                 end
               end
    end

    def check_c_dir_entry_static_header_length(buf) # :nodoc:
      return unless buf.nil? || buf.bytesize != ::Zip::CDIR_ENTRY_STATIC_HEADER_LENGTH

      raise Error, 'Premature end of file. Not enough data for zip cdir entry header'
    end

    def check_c_dir_entry_signature # :nodoc:
      return if @header_signature == ::Zip::CENTRAL_DIRECTORY_ENTRY_SIGNATURE

      raise Error, "Zip local header magic not found at location '#{local_header_offset}'"
    end

    def check_c_dir_entry_comment_size # :nodoc:
      return if @comment && @comment.bytesize == @comment_length

      raise ::Zip::Error, 'Truncated cdir zip entry header'
    end

    def read_c_dir_entry(io) # :nodoc:
      @dirty = false # No changes at this point.
      static_sized_fields_buf = io.read(::Zip::CDIR_ENTRY_STATIC_HEADER_LENGTH)
      check_c_dir_entry_static_header_length(static_sized_fields_buf)
      unpack_c_dir_entry(static_sized_fields_buf)
      check_c_dir_entry_signature
      set_time(@last_mod_date, @last_mod_time)

      @name = io.read(@name_length)
      if ::Zip.force_entry_names_encoding
        @name.force_encoding(::Zip.force_entry_names_encoding)
      end
      @name.tr!('\\', '/') # Normalise filepath separators after encoding set.

      read_extra_field(io.read(@extra_length))
      @comment = io.read(@comment_length)
      check_c_dir_entry_comment_size
      set_ftype_from_c_dir_entry
      parse_zip64_extra(false)
      parse_aes_extra
    end

    def pack_c_dir_entry # :nodoc:
      zip64 = @extra[:zip64]
      [
        @header_signature,
        @version, # version of encoding software
        @fstype, # filesystem type
        @version_needed_to_extract, # @versionNeededToExtract
        @gp_flags, # @gp_flags
        stored_compression_method,
        @time.to_binary_dos_time, # @last_mod_time
        @time.to_binary_dos_date, # @last_mod_date
        @crc,
        zip64 && zip64.compressed_size ? 0xFFFFFFFF : @compressed_size,
        zip64 && zip64.original_size ? 0xFFFFFFFF : (@size || 0),
        name_size,
        @extra ? @extra.c_dir_size : 0,
        comment_size,
        zip64 && zip64.disk_start_number ? 0xFFFF : 0, # disk number start
        @internal_file_attributes, # file type (binary=0, text=1)
        @external_file_attributes, # native filesystem attributes
        zip64 && zip64.relative_header_offset ? 0xFFFFFFFF : @local_header_offset
      ].pack('VCCvvvvvVVVvvvvvVV')
    end

    def write_c_dir_entry(io, suppress_extra_fields: false) # :nodoc:
      prep_cdir_zip64_extra

      case @fstype
      when ::Zip::FSTYPE_UNIX
        ft = case ftype
             when :file
               @unix_perms ||= 0o644
               ::Zip::FILE_TYPE_FILE
             when :directory
               @unix_perms ||= 0o755
               ::Zip::FILE_TYPE_DIR
             when :symlink
               @unix_perms ||= 0o755
               ::Zip::FILE_TYPE_SYMLINK
             end

        unless ft.nil?
          @external_file_attributes = ((ft << 12) | (@unix_perms & 0o7777)) << 16
        end
      end

      @extra.suppress_fields!(suppress_extra_fields) if suppress_extra_fields
      io << pack_c_dir_entry

      io << @name
      io << (@extra ? @extra.to_c_dir_bin : '')
      io << @comment
    end

    def cdir_header_size # :nodoc:
      CDIR_ENTRY_STATIC_HEADER_LENGTH + name_size +
        (@extra ? @extra.c_dir_size : 0) + comment_size
    end

    def load_local_extra_field
      return unless @local_extra_field_deferred

      get_raw_input_stream do |io|
        position = io.tell
        begin
          io.seek(local_header_offset, IO::SEEK_SET)
          merge_local_extra_field(::Zip::Entry.read_local_entry(io))
        ensure
          io.seek(position, IO::SEEK_SET)
        end
      end
    end

    private

    def merge_local_extra_field(local_entry)
      return unless @local_extra_field_deferred && local_entry

      @local_extra_field_deferred = false
      read_extra_field(local_entry.extra.to_local_bin, local: true)
    end
  end
end
