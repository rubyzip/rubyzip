#!/usr/bin/env ruby

require 'ftools'
require 'zip'

class String
  def endsWith(aString)
    aStringSize = aString.size
    slice(-aStringSize, aStringSize) == aString 
  end

  def ensureEnd(aString)
    endsWith(aString) ? self : self + aString
  end

end


module Glob

  class GlobPattern
    def initialize(globPatternString)
      @globPatternString = globPatternString
      @trailingSlash = globPatternString.endsWith(File::SEPARATOR)
      @globPatternElements = globPatternString.split(File::SEPARATOR).map { 
	|globElement| 
	GlobPattern.toRegexp(globElement)
      }
    end
    
    def ===(aFilePath)
      return false if FilePath.size(aFilePath) != size
      return false if @trailingSlash && ! FilePath.isDirectory(aFilePath)
      @globPatternElements.each_with_index { 
	|globElement, index|
	return false if ! (globElement === FilePath.elements(aFilePath)[index])
      }
      true
    end
    
    def self.toRegexp(globPattern)
      return Regexp.new("^"+globPattern.
			gsub(/\?/, "#{NOT_PATH_SEPARATOR}").
			gsub(/\*/, "#{NOT_PATH_SEPARATOR}*")+
			%Q{/?$})
    end
    
    
    def size
      @globPatternElements.size
    end
    
    NOT_PATH_SEPARATOR = "[^\\#{File::SEPARATOR}]"
  end
  
  # This class follows the Fly-weight pattern
  class FilePath
    def self.size(aFilePath)
      elements(aFilePath).size
    end
    
    def self.elements(aFilePath)
      aFilePath.to_s.split(File::SEPARATOR)
    end

    def self.isDirectory(aFilePath)
      aFilePath.to_s.endsWith(File::SEPARATOR)
    end

    def self.basename(aFilePath)
      aFilePath.to_s.slice(Regexp.new("#{GlobPattern::NOT_PATH_SEPARATOR}*(#{File::SEPARATOR})?$"))
    end

    def self.dirname(aFilePath)
      aFilePath.to_s.sub(Regexp.new("#{GlobPattern::NOT_PATH_SEPARATOR}*(#{File::SEPARATOR})?$"),
			 "")
    end
  end
  
  def self.glob(pathList, globPattern)
    expandPathList(pathList).grep(GlobPattern.new(globPattern))
  end
  

  def self.expandPathList(pathList)
    result = Hash.new
    pathList.each {
      |path|
      expandPath(path).each { |path| result[path] = path }
    }
    result.keys
  end

  # expands "rip/rap/rup" to ["rip/", "rip/rap/", "rip/rap/rup"]
  def self.expandPath(path)
    elements = path.scan(/[^\/]+\/?/)
    accumulatedList = []
    elements.map {
      |element|
      (accumulatedList << element).join
    }
  end

end # end of Glob module


# Relies on:
# * extractEntry(src, dst)
# ** src may be a string or an entry object native to the container (e.g. ZipEntry for ZipFile) 
# ** dst is a string
module FileArchive
  RECURSIVE = true
  NONRECURSIVE = false

  # src can be String, ZipEntry or Enumerable of either
  def extract(src, dst, recursive = NONRECURSIVE, 
	      continueOnExistsProc = proc { false }, 
	      createDestDirectoryProc = proc { true } )
    selectedEntries = expandSelection(src)
    case (selectedEntries.size)
    when 0
      raise Zip::ZipNoSuchEntryError, "'#{src}' not found in archive #{self.to_s}"
    when 1
      extractSingle(selectedEntries[0], dst, recursive, 
		    continueOnExistsProc, createDestDirectoryProc)
    else
      extractMultiple(selectedEntries, dst, recursive,
		      continueOnExistsProc, createDestDirectoryProc)
    end
  end

  def extractMultiple(srcList, dst, recursive, continueOnExistsProc, createDestDirectoryProc)
    FileArchive.ensureDirectory(dst, &createDestDirectoryProc)
    srcList.each { 
      |srcFilename| 
      extractSingle(srcFilename, dst, recursive, continueOnExistsProc, createDestDirectoryProc) 
    }
  end
  private :extractMultiple

  def extractSingle(src, dst, recursive, continueOnExistsProc, createDestDirectoryProc)
    destFilename = destinationFilename(src, dst)
    extractEntry(src, destFilename, &continueOnExistsProc)
    if (recursive && Glob::FilePath.isDirectory(src))
      extract(src+"*", destFilename.ensureEnd(File::SEPARATOR),
	      recursive, continueOnExistsProc, createDestDirectoryProc)
    end
  end
  private :extractSingle

  def destinationFilename(sourceFilePath, destinationPath)
    if File.directory?(destinationPath)
      return destinationPath.ensureEnd(File::SEPARATOR) + Glob::FilePath.basename(sourceFilePath)
    else
      return sourceFilePath.endsWith(File::SEPARATOR)? 
      destinationPath.ensureEnd(File::SEPARATOR) : destinationPath	
    end
  end
  private :destinationFilename

  # if selection is a string or a regexp it is expanded to a list of entries
  # otherwise selection is returned unmodified
  def expandSelection(selection)
    case selection
    when String then return Glob.glob(entries, selection)
    when Regexp then return entries.select { |entry| entry.to_s =~ selection }
    else return selection
    end
  end

  # If filepath is a file raises exception. 
  # If filepath doesn't exist create if createDirectoryProc
  def self.ensureDirectory(filepath, &createDirectoryProc)
    if File.exists?(filepath) && File.directory?(filepath)
      return
    elsif File.exists?(filepath) && ! File.directory?(filepath)
      raise Errno::EEXIST, 
	"Could not create directory '#{filepath}' - a file already exists with that name"
    elsif createDirectoryProc.call
      Dir.mkdir(filepath) # replace with something that does mkdir -p (create all dirs)
    else
      raise Errno::ENOENT, "No such file or directory - '#{filepath}'"
    end
  end

end



