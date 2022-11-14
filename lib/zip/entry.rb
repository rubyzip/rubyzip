# frozen_string_literal: true

require 'pathname'

require_relative 'dirtyable'

module Zip
  class Entry
    include Dirtyable

    STORED   = ::Zip::COMPRESSION_METHOD_STORE
    DEFLATED = ::Zip::COMPRESSION_METHOD_DEFLATE

    # Language encoding flag (EFS) bit
    EFS = 0b100000000000

    # Compression level flags (used as part of the gp flags).
    COMPRESSION_LEVEL_SUPERFAST_GPFLAG = 0b110
    COMPRESSION_LEVEL_FAST_GPFLAG = 0b100
    COMPRESSION_LEVEL_MAX_GPFLAG = 0b010

    attr_accessor :comment, :compressed_size, :follow_symlinks, :name,
                  :restore_ownership, :restore_permissions, :restore_times,
                  :unix_gid, :unix_perms, :unix_uid

    attr_accessor :crc, :external_file_attributes, :fstype, :gp_flags,
                  :internal_file_attributes, :local_header_offset # :nodoc:

    attr_reader :extra, :compression_level, :filepath # :nodoc:

    attr_writer :size # :nodoc:

    mark_dirty :comment=, :compressed_size=, :external_file_attributes=,
               :fstype=, :gp_flags=, :name=, :size=,
               :unix_gid=, :unix_perms=, :unix_uid=

    def set_default_vars_values
      @local_header_offset      = 0
      @local_header_size        = nil # not known until local entry is created or read
      @internal_file_attributes = 1
      @external_file_attributes = 0
      @header_signature         = ::Zip::CENTRAL_DIRECTORY_ENTRY_SIGNATURE

      @version_needed_to_extract = VERSION_NEEDED_TO_EXTRACT
      @version                   = VERSION_MADE_BY

      @ftype           = nil          # unspecified or unknown
      @filepath        = nil
      @gp_flags        = 0
      if ::Zip.unicode_names
        @gp_flags |= EFS
        @version = 63
      end
      @follow_symlinks = false

      @restore_times       = DEFAULT_RESTORE_OPTIONS[:restore_times]
      @restore_permissions = DEFAULT_RESTORE_OPTIONS[:restore_permissions]
      @restore_ownership   = DEFAULT_RESTORE_OPTIONS[:restore_ownership]
      # BUG: need an extra field to support uid/gid's
      @unix_uid            = nil
      @unix_gid            = nil
      @unix_perms          = nil
    end

    def check_name(name)
      raise EntryNameError, name if name.start_with?('/')
      raise EntryNameError if name.length > 65_535
    end

    def initialize(
      zipfile = '', name = '',
      comment: '', size: nil, compressed_size: 0, crc: 0,
      compression_method: DEFLATED,
      compression_level: ::Zip.default_compression,
      time: ::Zip::DOSTime.now, extra: ::Zip::ExtraField.new
    )
      super()
      @name = name
      check_name(@name)

      set_default_vars_values
      @fstype = ::Zip::RUNNING_ON_WINDOWS ? ::Zip::FSTYPE_FAT : ::Zip::FSTYPE_UNIX

      @zipfile            = zipfile
      @comment            = comment || ''
      @compression_method = compression_method || DEFLATED
      @compression_level  = compression_level || ::Zip.default_compression
      @compressed_size    = compressed_size || 0
      @crc                = crc || 0
      @size               = size
      @time               = case time
                            when ::Zip::DOSTime
                              time
                            when Time
                              ::Zip::DOSTime.from_time(time)
                            else
                              ::Zip::DOSTime.now
                            end
      @extra              =
        extra.kind_of?(ExtraField) ? extra : ExtraField.new(extra.to_s)

      set_compression_level_flags
    end

    def encrypted?
      gp_flags & 1 == 1
    end

    def incomplete?
      gp_flags & 8 == 8
    end

    def size
      @size || 0
    end

    def time(component: :mtime)
      time =
        if @extra['UniversalTime']
          @extra['UniversalTime'].send(component)
        elsif @extra['NTFS']
          @extra['NTFS'].send(component)
        end

      # Standard time field in central directory has local time
      # under archive creator. Then, we can't get timezone.
      time || (@time if component == :mtime)
    end

    alias mtime time

    def atime
      time(component: :atime)
    end

    def ctime
      time(component: :ctime)
    end

    def time=(value, component: :mtime)
      @dirty = true
      unless @extra.member?('UniversalTime') || @extra.member?('NTFS')
        @extra.create('UniversalTime')
      end

      value = DOSTime.from_time(value)
      comp = "#{component}=" unless component.to_s.end_with?('=')
      (@extra['UniversalTime'] || @extra['NTFS']).send(comp, value)
      @time = value if component == :mtime
    end

    alias mtime= time=

    def atime=(value)
      send(:time=, value, component: :atime)
    end

    def ctime=(value)
      send(:time=, value, component: :ctime)
    end

    def compression_method
      return STORED if ftype == :directory || @compression_level == 0

      @compression_method
    end

    def compression_method=(method)
      @dirty = true
      @compression_method = (ftype == :directory ? STORED : method)
    end

    def zip64?
      !@extra['Zip64'].nil?
    end

    def file_type_is?(type)
      ftype == type
    end

    def ftype # :nodoc:
      @ftype ||= name_is_directory? ? :directory : :file
    end

    # Dynamic checkers
    %w[directory file symlink].each do |k|
      define_method "#{k}?" do
        file_type_is?(k.to_sym)
      end
    end

    def name_is_directory? #:nodoc:all
      @name.end_with?('/')
    end

    # Is the name a relative path, free of `..` patterns that could lead to
    # path traversal attacks? This does NOT handle symlinks; if the path
    # contains symlinks, this check is NOT enough to guarantee safety.
    def name_safe?
      cleanpath = Pathname.new(@name).cleanpath
      return false unless cleanpath.relative?

      root = ::File::SEPARATOR
      naive = ::File.join(root, cleanpath.to_s)
      # Allow for Windows drive mappings at the root.
      ::File.absolute_path(cleanpath.to_s, root).match?(/([A-Z]:)?#{naive}/i)
    end

    def local_entry_offset #:nodoc:all
      local_header_offset + @local_header_size
    end

    def name_size
      @name ? @name.bytesize : 0
    end

    def extra_size
      @extra ? @extra.local_size : 0
    end

    def comment_size
      @comment ? @comment.bytesize : 0
    end

    def calculate_local_header_size #:nodoc:all
      LOCAL_ENTRY_STATIC_HEADER_LENGTH + name_size + extra_size
    end

    # check before rewriting an entry (after file sizes are known)
    # that we didn't change the header size (and thus clobber file data or something)
    def verify_local_header_size!
      return if @local_header_size.nil?

      new_size = calculate_local_header_size
      return unless @local_header_size != new_size

      raise Error,
            "Local header size changed (#{@local_header_size} -> #{new_size})"
    end

    def cdir_header_size #:nodoc:all
      CDIR_ENTRY_STATIC_HEADER_LENGTH + name_size +
        (@extra ? @extra.c_dir_size : 0) + comment_size
    end

    def next_header_offset #:nodoc:all
      local_entry_offset + compressed_size
    end

    # Extracts entry to file dest_path (defaults to @name).
    # NB: The caller is responsible for making sure dest_path is safe, if it
    # is passed.
    def extract(dest_path = nil, &block)
      if dest_path.nil? && !name_safe?
        warn "WARNING: skipped '#{@name}' as unsafe."
        return self
      end

      dest_path ||= @name
      block ||= proc { ::Zip.on_exists_proc }

      raise "unknown file type #{inspect}" unless directory? || file? || symlink?

      __send__("create_#{ftype}", dest_path, &block)
      self
    end

    def to_s
      @name
    end

    class << self
      def read_c_dir_entry(io) #:nodoc:all
        path = if io.respond_to?(:path)
                 io.path
               else
                 io
               end
        entry = new(path)
        entry.read_c_dir_entry(io)
        entry
      rescue Error
        nil
      end

      def read_local_entry(io)
        entry = new(io)
        entry.read_local_entry(io)
        entry
      rescue SplitArchiveError
        raise
      rescue Error
        nil
      end
    end

    def unpack_local_entry(buf)
      @header_signature,
        @version,
        @fstype,
        @gp_flags,
        @compression_method,
        @last_mod_time,
        @last_mod_date,
        @crc,
        @compressed_size,
        @size,
        @name_length,
        @extra_length = buf.unpack('VCCvvvvVVVvv')
    end

    def read_local_entry(io) #:nodoc:all
      @dirty = false # No changes at this point.
      @local_header_offset = io.tell

      static_sized_fields_buf = io.read(::Zip::LOCAL_ENTRY_STATIC_HEADER_LENGTH) || ''

      unless static_sized_fields_buf.bytesize == ::Zip::LOCAL_ENTRY_STATIC_HEADER_LENGTH
        raise Error, 'Premature end of file. Not enough data for zip entry local header'
      end

      unpack_local_entry(static_sized_fields_buf)

      unless @header_signature == LOCAL_ENTRY_SIGNATURE
        if @header_signature == SPLIT_FILE_SIGNATURE
          raise SplitArchiveError
        end

        raise Error, "Zip local header magic not found at location '#{local_header_offset}'"
      end

      set_time(@last_mod_date, @last_mod_time)

      @name = io.read(@name_length)
      if ::Zip.force_entry_names_encoding
        @name.force_encoding(::Zip.force_entry_names_encoding)
      end
      @name.tr!('\\', '/') # Normalise filepath separators after encoding set.

      # We need to do this here because `initialize` has so many side-effects.
      # :-(
      @ftype = name_is_directory? ? :directory : :file

      extra = io.read(@extra_length)
      if extra && extra.bytesize != @extra_length
        raise ::Zip::Error, 'Truncated local zip entry header'
      end

      read_extra_field(extra, local: true)
      parse_zip64_extra(true)
      @local_header_size = calculate_local_header_size
    end

    def pack_local_entry
      zip64 = @extra['Zip64']
      [::Zip::LOCAL_ENTRY_SIGNATURE,
       @version_needed_to_extract, # version needed to extract
       @gp_flags, # @gp_flags
       compression_method,
       @time.to_binary_dos_time, # @last_mod_time
       @time.to_binary_dos_date, # @last_mod_date
       @crc,
       zip64 && zip64.compressed_size ? 0xFFFFFFFF : @compressed_size,
       zip64 && zip64.original_size ? 0xFFFFFFFF : (@size || 0),
       name_size,
       @extra ? @extra.local_size : 0].pack('VvvvvvVVVvv')
    end

    def write_local_entry(io, rewrite: false) #:nodoc:all
      prep_local_zip64_extra
      verify_local_header_size! if rewrite
      @local_header_offset = io.tell

      io << pack_local_entry

      io << @name
      io << @extra.to_local_bin if @extra
      @local_header_size = io.tell - @local_header_offset
    end

    def unpack_c_dir_entry(buf)
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
        @local_header_offset,
        @name,
        @extra,
        @comment = buf.unpack('VCCvvvvvVVVvvvvvVV')
    end

    def set_ftype_from_c_dir_entry
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

    def check_c_dir_entry_static_header_length(buf)
      return unless buf.nil? || buf.bytesize != ::Zip::CDIR_ENTRY_STATIC_HEADER_LENGTH

      raise Error, 'Premature end of file. Not enough data for zip cdir entry header'
    end

    def check_c_dir_entry_signature
      return if @header_signature == ::Zip::CENTRAL_DIRECTORY_ENTRY_SIGNATURE

      raise Error, "Zip local header magic not found at location '#{local_header_offset}'"
    end

    def check_c_dir_entry_comment_size
      return if @comment && @comment.bytesize == @comment_length

      raise ::Zip::Error, 'Truncated cdir zip entry header'
    end

    def read_extra_field(buf, local: false)
      if @extra.kind_of?(::Zip::ExtraField)
        @extra.merge(buf, local: local) if buf
      else
        @extra = ::Zip::ExtraField.new(buf, local: local)
      end
    end

    def read_c_dir_entry(io) #:nodoc:all
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
    end

    def file_stat(path) # :nodoc:
      if @follow_symlinks
        ::File.stat(path)
      else
        ::File.lstat(path)
      end
    end

    def get_extra_attributes_from_path(path) # :nodoc:
      stat = file_stat(path)
      @time = DOSTime.from_time(stat.mtime)
      return if ::Zip::RUNNING_ON_WINDOWS

      @unix_uid   = stat.uid
      @unix_gid   = stat.gid
      @unix_perms = stat.mode & 0o7777
    end

    # rubocop:disable Style/GuardClause
    def set_unix_attributes_on_path(dest_path)
      # Ignore setuid/setgid bits by default. Honour if @restore_ownership.
      unix_perms_mask = (@restore_ownership ? 0o7777 : 0o1777)
      if @restore_permissions && @unix_perms
        ::FileUtils.chmod(@unix_perms & unix_perms_mask, dest_path)
      end
      if @restore_ownership && @unix_uid && @unix_gid && ::Process.egid == 0
        ::FileUtils.chown(@unix_uid, @unix_gid, dest_path)
      end
    end
    # rubocop:enable Style/GuardClause

    def set_extra_attributes_on_path(dest_path) # :nodoc:
      return unless file? || directory?

      case @fstype
      when ::Zip::FSTYPE_UNIX
        set_unix_attributes_on_path(dest_path)
      end

      # Restore the timestamp on a file. This will either have come from the
      # original source file that was copied into the archive, or from the
      # creation date of the archive if there was no original source file.
      ::FileUtils.touch(dest_path, mtime: time) if @restore_times
    end

    def pack_c_dir_entry
      zip64 = @extra['Zip64']
      [
        @header_signature,
        @version, # version of encoding software
        @fstype, # filesystem type
        @version_needed_to_extract, # @versionNeededToExtract
        @gp_flags, # @gp_flags
        compression_method,
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
        zip64 && zip64.relative_header_offset ? 0xFFFFFFFF : @local_header_offset,
        @name,
        @extra,
        @comment
      ].pack('VCCvvvvvVVVvvvvvVV')
    end

    def write_c_dir_entry(io) #:nodoc:all
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
          @external_file_attributes = (ft << 12 | (@unix_perms & 0o7777)) << 16
        end
      end

      io << pack_c_dir_entry

      io << @name
      io << (@extra ? @extra.to_c_dir_bin : '')
      io << @comment
    end

    def ==(other)
      return false unless other.class == self.class

      # Compares contents of local entry and exposed fields
      %w[compression_method crc compressed_size size name extra filepath time].all? do |k|
        other.__send__(k.to_sym) == __send__(k.to_sym)
      end
    end

    def <=>(other)
      to_s <=> other.to_s
    end

    # Returns an IO like object for the given ZipEntry.
    # Warning: may behave weird with symlinks.
    def get_input_stream(&block)
      if ftype == :directory
        yield ::Zip::NullInputStream if block
        ::Zip::NullInputStream
      elsif @filepath
        case ftype
        when :file
          ::File.open(@filepath, 'rb', &block)
        when :symlink
          linkpath = ::File.readlink(@filepath)
          stringio = ::StringIO.new(linkpath)
          yield(stringio) if block
          stringio
        else
          raise "unknown @file_type #{ftype}"
        end
      else
        zis = ::Zip::InputStream.new(@zipfile, offset: local_header_offset)
        zis.instance_variable_set(:@complete_entry, self)
        zis.get_next_entry
        if block
          begin
            yield(zis)
          ensure
            zis.close
          end
        else
          zis
        end
      end
    end

    def gather_fileinfo_from_srcpath(src_path) # :nodoc:
      stat   = file_stat(src_path)
      @ftype = case stat.ftype
               when 'file'
                 if name_is_directory?
                   raise ArgumentError,
                         "entry name '#{newEntry}' indicates directory entry, but " \
                             "'#{src_path}' is not a directory"
                 end
                 :file
               when 'directory'
                 @name += '/' unless name_is_directory?
                 :directory
               when 'link'
                 if name_is_directory?
                   raise ArgumentError,
                         "entry name '#{newEntry}' indicates directory entry, but " \
                             "'#{src_path}' is not a directory"
                 end
                 :symlink
               else
                 raise "unknown file type: #{src_path.inspect} #{stat.inspect}"
               end

      @filepath = src_path
      @size = stat.size
      get_extra_attributes_from_path(@filepath)
    end

    def write_to_zip_output_stream(zip_output_stream) #:nodoc:all
      if ftype == :directory
        zip_output_stream.put_next_entry(self)
      elsif @filepath
        zip_output_stream.put_next_entry(self)
        get_input_stream do |is|
          ::Zip::IOExtras.copy_stream(zip_output_stream, is)
        end
      else
        zip_output_stream.copy_raw_entry(self)
      end
    end

    def parent_as_string
      entry_name  = name.chomp('/')
      slash_index = entry_name.rindex('/')
      slash_index ? entry_name.slice(0, slash_index + 1) : nil
    end

    def get_raw_input_stream(&block)
      if @zipfile.respond_to?(:seek) && @zipfile.respond_to?(:read)
        yield @zipfile
      else
        ::File.open(@zipfile, 'rb', &block)
      end
    end

    def clean_up
      @dirty = false # Any changes are written at this point.
    end

    private

    def set_time(binary_dos_date, binary_dos_time)
      @time = ::Zip::DOSTime.parse_binary_dos_format(binary_dos_date, binary_dos_time)
    rescue ArgumentError
      warn 'WARNING: invalid date/time in zip entry.' if ::Zip.warn_invalid_date
    end

    def create_file(dest_path, _continue_on_exists_proc = proc { Zip.continue_on_exists_proc })
      if ::File.exist?(dest_path) && !yield(self, dest_path)
        raise ::Zip::DestinationExistsError, dest_path
      end

      ::File.open(dest_path, 'wb') do |os|
        get_input_stream do |is|
          bytes_written = 0
          warned = false
          buf = +''
          while (buf = is.sysread(::Zip::Decompressor::CHUNK_SIZE, buf))
            os << buf
            bytes_written += buf.bytesize
            next unless bytes_written > size && !warned

            error = ::Zip::EntrySizeError.new(self)
            raise error if ::Zip.validate_entry_sizes

            warn "WARNING: #{error.message}"
            warned = true
          end
        end
      end

      set_extra_attributes_on_path(dest_path)
    end

    def create_directory(dest_path)
      return if ::File.directory?(dest_path)

      if ::File.exist?(dest_path)
        raise ::Zip::DestinationExistsError, dest_path unless block_given? && yield(self, dest_path)

        ::FileUtils.rm_f dest_path
      end

      ::FileUtils.mkdir_p(dest_path)
      set_extra_attributes_on_path(dest_path)
    end

    # BUG: create_symlink() does not use &block
    def create_symlink(dest_path)
      # TODO: Symlinks pose security challenges. Symlink support temporarily
      # removed in view of https://github.com/rubyzip/rubyzip/issues/369 .
      warn "WARNING: skipped symlink '#{dest_path}'."
    end

    # apply missing data from the zip64 extra information field, if present
    # (required when file sizes exceed 2**32, but can be used for all files)
    def parse_zip64_extra(for_local_header) #:nodoc:all
      return unless zip64?

      if for_local_header
        @size, @compressed_size = @extra['Zip64'].parse(@size, @compressed_size)
      else
        @size, @compressed_size, @local_header_offset = @extra['Zip64'].parse(
          @size, @compressed_size, @local_header_offset
        )
      end
    end

    # For DEFLATED compression *only*: set the general purpose flags 1 and 2 to
    # indicate compression level. This seems to be mainly cosmetic but they are
    # generally set by other tools - including in docx files. It is these flags
    # that are used by commandline tools (and elsewhere) to give an indication
    # of how compressed a file is. See the PKWARE APPNOTE for more information:
    # https://pkware.cachefly.net/webdocs/casestudies/APPNOTE.TXT
    #
    # It's safe to simply OR these flags here as compression_level is read only.
    def set_compression_level_flags
      return unless compression_method == DEFLATED

      case @compression_level
      when 1
        @gp_flags |= COMPRESSION_LEVEL_SUPERFAST_GPFLAG
      when 2
        @gp_flags |= COMPRESSION_LEVEL_FAST_GPFLAG
      when 8, 9
        @gp_flags |= COMPRESSION_LEVEL_MAX_GPFLAG
      end
    end

    # rubocop:disable Style/GuardClause
    def prep_local_zip64_extra
      return unless ::Zip.write_zip64_support
      return if (!zip64? && @size && @size < 0xFFFFFFFF) || !file?

      # Might not know size here, so need ZIP64 just in case.
      # If we already have a ZIP64 extra (placeholder) then we must fill it in.
      if zip64? || @size.nil? || @size >= 0xFFFFFFFF || @compressed_size >= 0xFFFFFFFF
        @version_needed_to_extract = VERSION_NEEDED_TO_EXTRACT_ZIP64
        zip64 = @extra['Zip64'] || @extra.create('Zip64')

        # Local header always includes size and compressed size.
        zip64.original_size = @size || 0
        zip64.compressed_size = @compressed_size
      end
    end

    def prep_cdir_zip64_extra
      return unless ::Zip.write_zip64_support

      if (@size && @size >= 0xFFFFFFFF) || @compressed_size >= 0xFFFFFFFF ||
         @local_header_offset >= 0xFFFFFFFF
        @version_needed_to_extract = VERSION_NEEDED_TO_EXTRACT_ZIP64
        zip64 = @extra['Zip64'] || @extra.create('Zip64')

        # Central directory entry entries include whichever fields are necessary.
        zip64.original_size = @size if @size && @size >= 0xFFFFFFFF
        zip64.compressed_size = @compressed_size if @compressed_size >= 0xFFFFFFFF
        zip64.relative_header_offset = @local_header_offset if @local_header_offset >= 0xFFFFFFFF
      end
    end
    # rubocop:enable Style/GuardClause
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
