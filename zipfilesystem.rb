#!/usr/bin/env ruby

require 'filearchive'

class ZipFileSystem
  
  def initialize(zipFile)
    @zipFile = zipFile
  end

  def dir
    @zipFsDir ||= Dir.new(@zipFile)
  end

  def file
    @zipFsDir ||= ZipFsFile.new(@zipFile)
  end

  class ZipFsFile
    def initialize(zipFile)
      @zipFile = zipFile
    end

    def exists?(fileName)
      @zipFile.findEntry(fileName) != nil
    end
    alias :exist? :exists?

    def directory?(fileName)
      entry = @zipFile.findEntry(fileName)
      entry != nil && entry.directory?
    end

    def open(fileName, openMode = "r", &block)
      raise StandardError, "openmode '#{openMode} not supported" unless openMode == "r"
      @zipFile.getInputStream(fileName, &block)
    end

    def size(fileName)
      @zipFile.getEntry(fileName).size
    end

    # nil for not found and nil for directories
    def size?(fileName)
      entry = @zipFile.findEntry(fileName)
      return (entry == nil || entry.directory?) ? nil : entry.size
    end

    def file?(fileName)
      entry = @zipFile.findEntry(fileName)
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

    def mtime(fileName)
      @zipFile.getEntry(fileName).mtime
    end

    def pipe?(filename)
      false
    end

    def blockdev?(filename)
      false
    end

    def symlink?(fileName)
      false
    end

    def socket?(fileName)
      false
    end

    def ftype(fileName)
      @zipFile.getEntry(fileName).directory? ? "directory" : "file"
    end
  end
end
