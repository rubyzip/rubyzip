module Zip
  class Entry
    STORED   = 0
    DEFLATED = 8
    # Language encoding flag (EFS) bit
    EFS = 0b100000000000

    attr_accessor :comment, :compressed_size, :crc, :extra, :compression_method,
                  :name, :size, :local_header_offset, :zipfile, :fstype, :external_file_attributes,
                  :gp_flags, :header_signature, :follow_symlinks,
                  :restore_times, :restore_permissions, :restore_ownership,
                  :unix_uid, :unix_gid, :unix_perms,
                  :dirty
    attr_reader :ftype, :filepath # :nodoc:

    def set_default_vars_values
      @local_header_offset      = 0
      @local_header_size        = 0
      @internal_file_attributes = 1
      @external_file_attributes = 0
      @header_signature         = ::Zip::CENTRAL_DIRECTORY_ENTRY_SIGNATURE

      @version_needed_to_extract = VERSION_NEEDED_TO_EXTRACT
      @version                   = 52 # this library's version

      @ftype           = nil          # unspecified or unknown
      @filepath        = nil
      @gp_flags        = 0
      if ::Zip.unicode_names
        @gp_flags |= EFS
        @version = 63
      end
      @follow_symlinks = false

      @restore_times       = true
      @restore_permissions = false
      @restore_ownership   = false
      # BUG: need an extra field to support uid/gid's
      @unix_uid            = nil
      @unix_gid            = nil
      @unix_perms          = nil
      #@posix_acl = nil
      #@ntfs_acl = nil
      @dirty               = false
    end

    def check_name(name)
      if name.start_with?('/')
        raise ::Zip::ZipEntryNameError, "Illegal ZipEntry name '#{name}', name must not start with /"
      end
    end

    def initialize(*args)
      name = args[1] || ''
      check_name(name)

      set_default_vars_values
      @fstype = ::Zip::RUNNING_ON_WINDOWS ? ::Zip::FSTYPE_FAT : ::Zip::FSTYPE_UNIX

      @zipfile            = args[0] || ''
      @name               = name
      @comment            = args[2] || ''
      @extra              = args[3] || ''
      @compressed_size    = args[4] || 0
      @crc                = args[5] || 0
      @compression_method = args[6] || ::Zip::Entry::DEFLATED
      @size               = args[7] || 0
      @time               = args[8] || ::Zip::DOSTime.now

      @ftype = name_is_directory? ? :directory : :file
      @extra = ::Zip::ExtraField.new(@extra.to_s) unless ::Zip::ExtraField === @extra
    end

    def time
      if @extra['UniversalTime']
        @extra['UniversalTime'].mtime
      else
        # Standard time field in central directory has local time
        # under archive creator. Then, we can't get timezone.
        @time
      end
    end

    alias :mtime :time

    def time=(value)
      unless @extra.member?('UniversalTime')
        @extra.create('UniversalTime')
      end
      @extra['UniversalTime'].mtime = value
      @time                         = value
    end

    def file_type_is?(type)
      raise ZipInternalError, "current filetype is unknown: #{self.inspect}" unless @ftype
      @ftype == type
    end

    # Dynamic checkers
    %w(directory file symlink).each do |k|
      define_method "#{k}?" do
        file_type_is?(k.to_sym)
      end
    end

    def name_is_directory? #:nodoc:all
      @name.end_with?('/')
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
      fix_zip64_sizes!
      LOCAL_ENTRY_STATIC_HEADER_LENGTH + name_size + extra_size
    end

    def cdir_header_size #:nodoc:all
      CDIR_ENTRY_STATIC_HEADER_LENGTH + name_size +
        (@extra ? @extra.c_dir_size : 0) + comment_size
    end

    def next_header_offset #:nodoc:all
      local_entry_offset + self.compressed_size
    end

    # Extracts entry to file dest_path (defaults to @name).
    def extract(dest_path = @name, &block)
      block ||= proc { ::Zip.on_exists_proc }

      if directory? || file? || symlink?
        self.__send__("create_#{@ftype}", dest_path, &block)
      else
        raise RuntimeError, "unknown file type #{self.inspect}"
      end

      self
    end

    def to_s
      @name
    end

    protected

    class << self
      def read_zip_short(io) # :nodoc:
        io.read(2).unpack('v')[0]
      end

      def read_zip_long(io) # :nodoc:
        io.read(4).unpack('V')[0]
      end

      def read_zip_64_long(io) # :nodoc:
        io.read(8).unpack('V')[0]
      end

      def read_c_dir_entry(io) #:nodoc:all
        entry = new(io.path)
        entry.read_c_dir_entry(io)
        entry
      rescue ZipError
        nil
      end

      def read_local_entry(io)
        entry = new(io.path)
        entry.read_local_entry(io)
        entry
      rescue ZipError
        nil
      end

    end

    public

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
      @local_header_offset = io.tell

      static_sized_fields_buf = io.read(::Zip::LOCAL_ENTRY_STATIC_HEADER_LENGTH)

      unless static_sized_fields_buf.bytesize == ::Zip::LOCAL_ENTRY_STATIC_HEADER_LENGTH
        raise ZipError, "Premature end of file. Not enough data for zip entry local header"
      end

      unpack_local_entry(static_sized_fields_buf)

      unless @header_signature == ::Zip::LOCAL_ENTRY_SIGNATURE
        raise ::Zip::ZipError, "Zip local header magic not found at location '#{local_header_offset}'"
      end
      set_time(@last_mod_date, @last_mod_time)

      @name = io.read(@name_length)
      extra = io.read(@extra_length)

      @name.gsub!('\\', '/')

      if extra && extra.bytesize != @extra_length
        raise ::Zip::ZipError, "Truncated local zip entry header"
      else
        if ::Zip::ExtraField === @extra
          @extra.merge(extra)
        else
          @extra = ::Zip::ExtraField.new(extra)
        end
      end
      @local_header_size = calculate_local_header_size
    end

    def pack_local_entry
      [::Zip::LOCAL_ENTRY_SIGNATURE,
       @version_needed_to_extract, # version needed to extract
       @gp_flags, # @gp_flags                  ,
       @compression_method,
       @time.to_binary_dos_time, # @last_mod_time              ,
       @time.to_binary_dos_date, # @last_mod_date              ,
       @crc,
       @compressed_size,
       @size,
       name_size,
       @extra ? @extra.local_size : 0].pack('VvvvvvVVVvv')
    end

    def write_local_entry(io) #:nodoc:all
      @local_header_offset = io.tell

      io << pack_local_entry

      io << @name
      io << (@extra ? @extra.to_local_bin : '')
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
                 @unix_perms = (@external_file_attributes >> 16) & 07777
                 case (@external_file_attributes >> 28)
                 when ::Zip::FILE_TYPE_DIR
                   :directory
                 when ::Zip::FILE_TYPE_FILE
                   :file
                 when ::Zip::FILE_TYPE_SYMLINK
                   :symlink
                 else
                   #best case guess for whether it is a file or not
                   #Otherwise this would be set to unknown and that entry would never be able to extracted
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
      unless buf.bytesize == ::Zip::CDIR_ENTRY_STATIC_HEADER_LENGTH
        raise ZipError, 'Premature end of file. Not enough data for zip cdir entry header'
      end
    end

    def check_c_dir_entry_signature
      unless header_signature == ::Zip::CENTRAL_DIRECTORY_ENTRY_SIGNATURE
        raise ZipError, "Zip local header magic not found at location '#{local_header_offset}'"
      end
    end

    def check_c_dir_entry_comment_size
      unless @comment && @comment.bytesize == @comment_length
        raise ::Zip::ZipError, "Truncated cdir zip entry header"
      end
    end

    def read_c_dir_extra_field(io)
      if @extra.is_a?(::Zip::ExtraField)
        @extra.merge(io.read(@extra_length))
      else
        @extra = ::Zip::ExtraField.new(io.read(@extra_length))
      end
    end

    def read_c_dir_entry(io) #:nodoc:all
      static_sized_fields_buf = io.read(::Zip::CDIR_ENTRY_STATIC_HEADER_LENGTH)
      check_c_dir_entry_static_header_length(static_sized_fields_buf)
      unpack_c_dir_entry(static_sized_fields_buf)
      check_c_dir_entry_signature
      set_time(@last_mod_date, @last_mod_time)
      @name = io.read(@name_length).gsub('\\', '/')
      read_c_dir_extra_field(io)
      @comment = io.read(@comment_length)
      check_c_dir_entry_comment_size
      set_ftype_from_c_dir_entry
      @local_header_size = calculate_local_header_size
    end

    def file_stat(path) # :nodoc:
      if @follow_symlinks
        ::File::stat(path)
      else
        ::File::lstat(path)
      end
    end

    def get_extra_attributes_from_path(path) # :nodoc:
      unless Zip::RUNNING_ON_WINDOWS
        stat        = file_stat(path)
        @unix_uid   = stat.uid
        @unix_gid   = stat.gid
        @unix_perms = stat.mode & 07777
      end
    end

    def set_unix_permissions_on_path(dest_path)
      # BUG: does not update timestamps into account
      # ignore setuid/setgid bits by default.  honor if @restore_ownership
      unix_perms_mask = 01777
      unix_perms_mask = 07777 if @restore_ownership
      ::FileUtils.chmod(@unix_perms & unix_perms_mask, dest_path) if @restore_permissions && @unix_perms
      ::FileUtils.chown(@unix_uid, @unix_gid, dest_path) if @restore_ownership && @unix_uid && @unix_gid && ::Process.egid == 0
      # File::utimes()
    end

    def set_extra_attributes_on_path(dest_path) # :nodoc:
      return unless (file? || directory?)

      case @fstype
      when ::Zip::FSTYPE_UNIX
        set_unix_permissions_on_path(dest_path)
      end
    end

    def pack_c_dir_entry
      [
        @header_signature,
        @version, # version of encoding software
        @fstype, # filesystem type
        @version_needed_to_extract, # @versionNeededToExtract           ,
        @gp_flags, # @gp_flags                          ,
        @compression_method,
        @time.to_binary_dos_time, # @last_mod_time                      ,
        @time.to_binary_dos_date, # @last_mod_date                      ,
        @crc,
        @compressed_size,
        @size,
        name_size,
        @extra ? @extra.c_dir_size : 0,
        comment_size,
        0, # disk number start
        @internal_file_attributes, # file type (binary=0, text=1)
        @external_file_attributes, # native filesystem attributes
        @local_header_offset,
        @name,
        @extra,
        @comment
      ].pack('VCCvvvvvVVVvvvvvVV')
    end

    def write_c_dir_entry(io) #:nodoc:all
      case @fstype
      when ::Zip::FSTYPE_UNIX
        ft = case @ftype
             when :file
               @unix_perms ||= 0644
               ::Zip::FILE_TYPE_FILE
             when :directory
               @unix_perms ||= 0755
               ::Zip::FILE_TYPE_DIR
             when :symlink
               @unix_perms ||= 0755
               ::Zip::FILE_TYPE_SYMLINK
             end

        unless ft.nil?
          @external_file_attributes = (ft << 12 | (@unix_perms & 07777)) << 16
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
      keys_equal = %w(compression_method crc compressed_size size name extra filepath).all? do |k|
        other.__send__(k.to_sym) == self.__send__(k.to_sym)
      end
      keys_equal && self.time.dos_equals(other.time)
    end

    def <=> (other)
      self.to_s <=> other.to_s
    end

    # Returns an IO like object for the given ZipEntry.
    # Warning: may behave weird with symlinks.
    def get_input_stream(&block)
      if @ftype == :directory
        yield(::Zip::NullInputStream.instance) if block_given?
        ::Zip::NullInputStream.instance
      elsif @filepath
        case @ftype
        when :file
          ::File.open(@filepath, 'rb', &block)
        when :symlink
          linkpath = ::File.readlink(@filepath)
          stringio = ::StringIO.new(linkpath)
          yield(stringio) if block_given?
          stringio
        else
          raise "unknown @file_type #{@ftype}"
        end
      else
        zis = ::Zip::InputStream.new(@zipfile, local_header_offset)
        zis.get_next_entry
        if block_given?
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
                         "entry name '#{newEntry}' indicates directory entry, but "+
                           "'#{src_path}' is not a directory"
                 end
                 :file
               when 'directory'
                 @name += "/" unless name_is_directory?
                 :directory
               when 'link'
                 if name_is_directory?
                   raise ArgumentError,
                         "entry name '#{newEntry}' indicates directory entry, but "+
                           "'#{src_path}' is not a directory"
                 end
                 :symlink
               else
                 raise RuntimeError, "unknown file type: #{src_path.inspect} #{stat.inspect}"
               end

      @filepath = src_path
      get_extra_attributes_from_path(@filepath)
    end

    def write_to_zip_output_stream(zip_output_stream) #:nodoc:all
      if @ftype == :directory
        zip_output_stream.put_next_entry(self)
      elsif @filepath
        zip_output_stream.put_next_entry(self, nil, nil, nil)
        get_input_stream { |is| ::Zip::IOExtras.copy_stream(zip_output_stream, is) }
      else
        zip_output_stream.copy_raw_entry(self)
      end
    end

    def parent_as_string
      entry_name  = name.chomp('/')
      slash_index = entry_name.rindex('/')
      slash_index ? entry_name.slice(0, slash_index+1) : nil
    end

    def get_raw_input_stream(&block)
      ::File.open(@zipfile, "rb", &block)
    end

    private

    def set_time(binary_dos_date, binary_dos_time)
      @time = ::Zip::DOSTime.parse_binary_dos_format(binary_dos_date, binary_dos_time)
    rescue ArgumentError
      puts "Invalid date/time in zip entry"
    end

    def create_file(dest_path, continue_on_exists_proc = proc { Zip.continue_on_exists_proc })
      if ::File.exists?(dest_path) && !yield(self, dest_path)
        raise ::Zip::ZipDestinationFileExistsError,
              "Destination '#{dest_path}' already exists"
      end
      ::File.open(dest_path, "wb") do |os|
        get_input_stream do |is|
          set_extra_attributes_on_path(dest_path)

          buf = ''
          while buf = is.sysread(::Zip::Decompressor::CHUNK_SIZE, buf)
            os << buf
          end
        end
      end
    end

    def create_directory(dest_path)
      return if ::File.directory?(dest_path)
      if ::File.exists?(dest_path)
        if block_given? && yield(self, dest_path)
          ::FileUtils::rm_f dest_path
        else
          raise ::Zip::ZipDestinationFileExistsError,
                "Cannot create directory '#{dest_path}'. "+
                  "A file already exists with that name"
        end
      end
      ::FileUtils.mkdir_p(dest_path)
      set_extra_attributes_on_path(dest_path)
    end

    # BUG: create_symlink() does not use &block
    def create_symlink(dest_path)
      stat = nil
      begin
        stat = ::File.lstat(dest_path)
      rescue Errno::ENOENT
      end

      io     = get_input_stream
      linkto = io.read

      if stat
        if stat.symlink?
          if ::File.readlink(dest_path) == linkto
            return
          else
            raise ZipDestinationFileExistsError,
                  "Cannot create symlink '#{dest_path}'. "+
                    "A symlink already exists with that name"
          end
        else
          raise ZipDestinationFileExistsError,
                "Cannot create symlink '#{dest_path}'. "+
                  "A file already exists with that name"
        end
      end

      ::File.symlink(linkto, dest_path)
    end

    def fix_zip64_sizes! #:nodoc:all
      if zip64 = @extra["Zip64"]
        @size = zip64.original_size
        @compressed_size = zip64.compressed_size
      end
    end

  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
