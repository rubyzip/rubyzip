#!/usr/bin/env ruby

require 'zip'

module Zip
  module ZipFileSystem
    
    
    def dir
      @zipFsDir ||= Dir.new(self)
    end
    
    def file
      @zipFsDir ||= ZipFsFile.new(self)
    end
    
    class ZipFsFile

      class ZipFsStat
        def initialize(zipFsFile, entryName)
          @zipFsFile = zipFsFile
          @entryName = entryName
        end
        
        def forward_invoke(msg)
          @zipFsFile.send(msg, @entryName)
        end

        def kind_of?(t)
          super || t == File::Stat 
        end
        
        forward_message :forward_invoke, :file?, :directory?, :pipe?, :chardev?
        forward_message :forward_invoke, :symlink?, :socket?, :blockdev?
        forward_message :forward_invoke, :readable?, :readable_real?
        forward_message :forward_invoke, :writable?, :writable_real?
        forward_message :forward_invoke, :executable?, :executable_real?
        forward_message :forward_invoke, :sticky?, :owned?, :grpowned?
        forward_message :forward_invoke, :setuid?, :setgid?
        forward_message :forward_invoke, :zero?
        forward_message :forward_invoke, :size, :size?
        forward_message :forward_invoke, :mtime, :atime, :ctime
        
        def blocks; nil; end

        def gid; 0; end

        def uid; 0; end

        def ino; 0; end

        def dev; 0; end

        def rdev; 0; end

        def rdev_major; 0; end

        def rdev_minor; 0; end

        def ftype
          if file?
            return "file"
          elsif directory?
            return "directory"
          else
            raise StandardError, "Unknown file type"
          end
        end

        def nlink; 1; end
        
        def blksize; nil; end
      end

      def initialize(zipFile)
	@zipFile = zipFile
      end
      
      def exists?(fileName)
	@zipFile.find_entry(fileName) != nil
      end
      alias :exist? :exists?
      
      # Permissions not implemented, so if the file exists it is accessible
      alias readable?        exists?
      alias readable_real?   exists?
      alias writable?        exists?
      alias writable_real?   exists?
      alias executable?      exists?
      alias executable_real? exists?
      alias owned?           exists?
      alias grpowned?        exists?

      def setuid?(fileName)
        false
      end

      def setgid?(fileName)
        false
      end
      
      def sticky?(fileName)
        false
      end

      def umask(*args)
        File.umask(*args)
      end

      def truncate(fileName, len)
        raise StandardError, "truncate not supported"
      end

      def directory?(fileName)
	entry = @zipFile.find_entry(fileName)
	entry != nil && entry.directory?
      end
      
      def open(fileName, openMode = "r", &block)
	raise StandardError, "openmode '#{openMode} not supported" unless openMode == "r"
	@zipFile.get_input_stream(fileName, &block)
      end

      def new(fileName, openMode = "r")
	open(fileName, openMode)
      end
      
      def size(fileName)
	@zipFile.get_entry(fileName).size
      end
      
      # nil for not found and nil for directories
      def size?(fileName)
	entry = @zipFile.find_entry(fileName)
	return (entry == nil || entry.directory?) ? nil : entry.size
      end
      
      def chown(ownerInt, groupInt, *filenames) 
        filenames.size
      end

      def chmod (modeInt, *filenames)
        filenames.each { 
          |elem|
          if ! exists?(elem)
            raise Errno::ENOENT, "No such file or directory - #{elem}"
          end
        }
        filenames.size
      end

      def zero?(fileName)
	sz = size(fileName)
	sz == nil || sz == 0
      rescue Errno::ENOENT
	false
      end
      
      def file?(fileName)
	entry = @zipFile.find_entry(fileName)
	entry != nil && entry.file?
      end      
      
      def dirname(fileName)
	::File.dirname(fileName)
      end
      
      def basename(fileName)
	::File.basename(fileName)
      end
      
      def split(fileName)
	::File.split(fileName)
      end
      
      def join(*fragments)
	::File.join(*fragments)
      end
      
      def utime(accessTime, *fileNames)
        raise StandardError, "utime not supported"
      end

      def mtime(fileName)
	@zipFile.get_entry(fileName).mtime
      end
      
      def atime(fileName)
        @zipFile.get_entry(fileName)
        nil
      end
      
      def ctime(fileName)
        @zipFile.get_entry(fileName)
        nil
      end

      def pipe?(filename)
	false
      end
      
      def blockdev?(filename)
	false
      end
      
      def chardev?(filename)
	false
      end
      
      def symlink?(fileName)
	false
      end
      
      def socket?(fileName)
	false
      end
      
      def ftype(fileName)
	@zipFile.get_entry(fileName).directory? ? "directory" : "file"
      end
      
      def readlink(fileName)
	raise NotImplementedError, "The readlink() function is not implemented to ZipFileSystem"
      end
      
      def symlink(fileName, symlinkName)
	raise NotImplementedError, "The symlink() function is not implemented to ZipFileSystem"
      end

      def link(fileName, symlinkName)
	raise NotImplementedError, "The link() function is not implemented to ZipFileSystem"
      end

      def pipe
	raise NotImplementedError, "The pipe() function is not implemented to ZipFileSystem"
      end

      def stat(fileName)
        if ! exists?(fileName)
          raise Errno::ENOENT, "No such file or directory - #{fileName}"
        end
        ZipFsStat.new(self, fileName)
      end

      alias lstat stat

      def readlines(fileName)
	open(fileName) { |is| is.readlines }
      end

      def popen(*args, &aProc)
	File.popen(*args, &aProc)
      end

      def foreach(fileName, aSep = $/, &aProc)
	open(fileName) { |is| is.each_line(aSep, &aProc) }
      end

      def delete(*args)
	args.each { 
	  |fileName|
	  if directory?(fileName)
	    raise Errno::EISDIR, "Is a directory - \"#{fileName}\""
	  end
	  @zipFile.remove(fileName) 
	}
      end

      def rename(fileToRename, newName)
        @zipFile.rename(fileToRename, newName) { true }
      end

      alias :unlink :delete

    end
  end

  class ZipFile
    include ZipFileSystem
  end
end

# Copyright (C) 2002, 2003 Thomas Sondergaard
# rubyzip is free software; you can redistribute it and/or
# modify it under the terms of the ruby license.
