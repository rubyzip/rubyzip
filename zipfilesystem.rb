#!/usr/bin/env ruby

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
  end
end
