#!/usr/bin/env ruby

require 'zip'

module Glob

  def self.glob(pathList, globPattern, recursive = false)
    expandPathList(pathList).grep(toRegexp(globPattern, recursive))
  end


  def self.toRegexp(globPattern, recursive)
    reducedGlobPattern = pruneLeadingAndTrailingSeparator(globPattern)
    return Regexp.new("^"+reducedGlobPattern.
		      gsub(/\?/, "#{NOT_PATH_SEPARATOR}?").
		      gsub(/\*/, "#{NOT_PATH_SEPARATOR}*")+
		      (recursive ? "(?:/.+)?" : "")+
		      "/?$")
  end


  def self.pruneLeadingAndTrailingSeparator(aString)
    aString.sub(/^\/?(.*?)\/?$/, '\1')
  end


  def self.expandPathList(pathList)
    result = Hash.new
    pathList.each {
      |path|
      expandPath(path).each { |path| result[path] = path }
    }
    result.keys
  end

  # expands "rip/rap/rup" to ["rip", "rip/rap", "rip/rap/rup"]
  def self.expandPath(path)
    prunedPath = pruneLeadingAndTrailingSeparator(path)
    elements = prunedPath.split("/")
    accumulatedList = []
    elements.map {
      |element|
      (accumulatedList << element).join("/")
    }
  end


  private
  NOT_PATH_SEPARATOR = "[^\\#{File::SEPARATOR}]"

end # end of Glob module


# Relies on:
# * extract(src, dst)
module FileArchive
  RECURSIVE = true

  def extract(src, dst, recursive = RECURSIVE)
    selectedEntries = Glob.glob(entries, src, recursive)
    if (selectedEntries.size == 0)
      raise Zip::ZipNoSuchEntryError, "'#{src}' not found in archive #{self.to_s}"
    end
    createDstAsDirectory = (selectedEntries.size == 1)
    selectedEntries.each {
      |srcEntryFull, srcEntryName|
      extractEntry(srcEntryFull, dst)
    }
  end
end

