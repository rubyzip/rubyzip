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

    def pipe?(filename)
      false
    end

    def open(fileName, openMode = "r", &block)
      raise StandardError, "openmode '#{openMode} not supported" unless openMode == "r"
      @zipFile.getInputStream(fileName, &block)
    end

    def size(fileName)
      @zipFile.getEntry(fileName).size
    end

    def file?(fileName)
      entry = @zipFile.findEntry(fileName)
      entry != nil && entry.file?
    end      

    def dirname(fileName)
      ::File.dirname(fileName)
    end

    def mtime(fileName)
      @zipFile.getEntry(fileName).mtime
    end

    def symlink?(fileName)
      false
    end

    def split(fileName)
      ::File.split(fileName)
    end
  end
end
